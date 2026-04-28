class CephClient < Formula
  desc "Ceph client tools and libraries"
  homepage "https://ceph.com"
  url "https://download.ceph.com/tarballs/ceph-18.2.8.tar.gz"
  sha256 "6a7d114f783bf8ae2a453f22d03d45761cf9f42aa146d191804a4980c8d8812c"
  revision 1

bottle do
    rebuild 1
    root_url "https://github.com/kilinrax/homebrew-ceph-client/releases/download/reef-18.2.8-1/"
    sha256 cellar: :any, sonoma: "sha256:326e324477fb627379d3b8b5eca6c916c049e95b23ed5c77ff385553e1bb9e33"
  end

  # depends_on "osxfuse"
  depends_on "cmake@3.26" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.11" => :build

  depends_on "boost@1.85" => :build
  depends_on "cython" => :build
  depends_on "doxygen"
  depends_on "fmt@8" => :build
  depends_on "icu4c" => :build
  depends_on "llvm@17" => :build
  depends_on "leveldb" => :build
  depends_on "lz4" => :build
  depends_on "lua@5.4" => :build
  depends_on "nss"
  depends_on "openssl" => :build
  depends_on "sphinx-doc" => :build
  depends_on "thrift" => :build
  depends_on "yasm"

  def caveats
    <<~EOS
      macFUSE must be installed prior to building this formula. macFUSE is also necessary
      if you plan to use the FUSE support of CephFS. You can either install macFUSE from
      https://osxfuse.github.io or use the following command:

      brew install --cask macfuse

      The fuse version shipped with osxfuse is too old to access the
      supplementary group IDs in cephfs.
      Thus you need to add this to your ceph.conf to avoid errors:

      [client]
      fuse_set_user_groups = false

    EOS
  end

  #resource "prettytable" do
  #  url "https://files.pythonhosted.org/packages/cb/7d/7e6bc4bd4abc49e9f4f5c4773bb43d1615e4b476d108d1b527318b9c6521/prettytable-3.2.0.tar.gz"
  #  sha256 "ae7d96c64100543dc61662b40a28f3b03c0f94a503ed121c6fca2782c5816f81"
  #end

  resource "PyYAML" do
    url "https://files.pythonhosted.org/packages/54/ed/79a089b6be93607fa5cdaedf301d7dfb23af5f25c398d5ead2525b063e17/pyyaml-6.0.2.tar.gz"
    sha256 "d584d9ec91ad65861cc08d42e834324ef890a082e591037abe114850ff7bbc3e2"
  end

  #resource "wcwidth" do
  #  url "https://files.pythonhosted.org/packages/89/38/459b727c381504f361832b9e5ace19966de1a235d73cdbdea91c771a1155/wcwidth-0.2.5.tar.gz"
  #  sha256 "c4d647b99872929fdb7bdcaa4fbe7f01413ed3d98077df798530e5b04f116c83"
  #end

  patch :DATA

  def install
    ENV["SDKROOT"] = MacOS.sdk_path
    ENV["HOMEBREW_CXXFLAGS"] = "-std=c++17"
    ENV["CXXFLAGS"] = "-std=c++17"
    ENV["CFLAGS"] = "-std=c17"
    ENV["CC"]  = Formula["llvm@17"].opt_bin/"clang"
    ENV["CXX"] = Formula["llvm@17"].opt_bin/"clang++"
    ENV.append "CXXFLAGS", " -Wno-return-type"
    ENV.prepend_path "PATH", Formula["python@3.11"].opt_bin
    ENV.prepend_path "PATH", Formula["llvm@17"].opt_bin
    ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["nss"].opt_lib}/pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["openssl"].opt_lib}/pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", "/usr/local/lib/pkgconfig"
    xy = Language::Python.major_minor_version "python3"
    ENV.prepend_create_path "PYTHONPATH", "#{Formula["cython"].opt_libexec}/lib/python#{xy}/site-packages"
    ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python#{xy}/site-packages"
    # XXX this array is now empty, so this is a no-op
    resources.each do |r|
      r.stage do
        system Formula["python@3.11"].opt_bin/"python3", "-m", "pip", "install",
            "--only-binary=:all:",
            # "--no-deps",
            #"--no-build-isolation",
            "--prefix=#{libexec}/vendor",
            "."
      end
    end

    dirs = %w[
      src/common
      src/include
      src/msg
    ]

    dirs.each do |dir|
      Dir["#{dir}/**/*.{h,cc,cpp}"].select { |f| File.file?(f) }.each do |file|
        text = File.read(file)
        next unless text.include?("std::result_of_t")

        File.write(
          file,
          text.gsub(/std::result_of_t<(\w+(?:&&?)?)\(([^)]*)\)>/) do
            callable = $1
            args = $2
            arg_types = args.split(",").map(&:strip).join(", ")
            "std::invoke_result_t<#{callable}, #{arg_types}>"
          end
        )
      end
    end

    # ceph 17
    #inreplace "src/include/compat.h",
    #  "#define aligned_free(ptr) free(ptr)",
    #  "#ifdef __cplusplus\n" \
    #  "#include <cstdlib>\n" \
    #  "inline void aligned_free(void* ptr) { ::free(ptr); }\n" \
    #  "#else\n" \
    #  "#include <stdlib.h>\n" \
    #  "static inline void aligned_free(void* ptr) { free(ptr); }\n" \
    #  "#endif"

    # ceph 18
    inreplace "src/osd/OSDMap.cc",
      "max_prims_per_osd = std::max(max_prims_per_osd, n_prims);",
      "max_prims_per_osd = std::max(max_prims_per_osd, (uint64_t)n_prims);"
    inreplace "src/osd/OSDMap.cc",
      "max_acting_prims_per_osd = std::max(max_acting_prims_per_osd, n_aprims);",
      "max_acting_prims_per_osd = std::max(max_acting_prims_per_osd, (uint64_t)n_aprims);"

    args = %W[
      -DDIAGNOSTICS_COLOR=always
      -DOPENSSL_ROOT_DIR=#{Formula["openssl"].opt_prefix}
      -DLUA_INCLUDE_DIR=#{Formula["lua@5.4"].opt_include}
      -DLUA_LIBRARY=#{Formula["lua@5.4"].opt_lib}/liblua.dylib
      -DBOOST_ROOT=#{Formula["boost@1.85"].opt_prefix}
      -DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}
      -DPython3_EXECUTABLE=#{Formula["python@3.11"].opt_bin}/python3.11
      -DBoost_NO_BOOST_CMAKE=ON
      -DBoost_NO_SYSTEM_PATHS=OFF
      -DBoost_USE_STATIC_LIBS=OFF
      -DBoost_USE_MULTITHREADED=OFF
      -DBoost_USE_STATIC_RUNTIME=OFF
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_CXX_EXTENSIONS=OFF
      -DCMAKE_CXX_STANDARD=17
      -DCMAKE_CXX_STANDARD_REQUIRED=ON
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
      -DWITH_BABELTRACE=OFF
      -DWITH_BLKDEV=OFF
      -DWITH_BLUESTORE=OFF
      -DWITH_BOOST=ON
      -DWITH_BUILD_TESTS=OFF
      -DWITH_CCACHE=OFF
      -DWITH_CEPHFS=ON
      -DWITH_EXTBLKDEV=OFF
      -DWITH_JAEGER=OFF
      -DWITH_KRBD=OFF
      -DWITH_LIBCEPHFS=ON
      -DWITH_LIBRADOS=ON
      -DWITH_LTTNG=OFF
      -DWITH_LZ4=OFF
      -DWITH_MANPAGE=ON
      -DWITH_MGR=OFF
      -DWITH_MGR_DASHBOARD_FRONTEND=OFF
      -DWITH_NBD=OFF
      -DWITH_OPENTELEMETRY=OFF
      -DWITH_OSD=OFF
      -DWITH_QAT=OFF
      -DWITH_QATZIP=OFF
      -DWITH_RBD_NBD=OFF
      -DWITH_RBD=ON
      -DWITH_PYBIND=OFF
      -DWITH_PYTHON_COMMON=OFF
      -DWITH_PYTHON3=3.11
      -DWITH_RADOS=ON
      -DWITH_RADOSGW=OFF
      -DWITH_RDMA=OFF
      -DWITH_SPDK=OFF
      -DWITH_SYSTEM_BOOST=ON
      -DWITH_SYSTEM_FMT=ON
      -DWITH_SYSTEMD=OFF
      -DWITH_TESTS=OFF
      -DWITH_TOOLS=ON
      -DWITH_TRACING=OFF
      -DWITH_XFS=OFF
      -DWITH_ZBD=OFF
    ]
    targets = %w[
      rados
      ceph-conf
      ceph-fuse
      cephfs
      rbd
      manpages
    ]
    mkdir "build" do
      system "cmake",
        "-G", "Ninja",
        "-D", "CMAKE_PREFIX_PATH=#{HOMEBREW_PREFIX}",
        "..", *args, *std_cmake_args

      # forcibly remove -lcap, which is linux only
      inreplace "build.ninja",
        " -lcap ",
        " "

      system "ninja", *targets
      executables = %w[
        bin/rados
        bin/rbd
        bin/ceph-fuse
      ]
      executables.each do |file|
        MachO.open(file).linked_dylibs.each do |dylib|
          unless dylib.start_with?("/tmp/")
            next
          end
          MachO::Tools.change_install_name(file, dylib, "#{lib}/#{dylib.split('/')[-1]}")
        end
      end
      %w[
        ceph
        ceph-conf
        ceph-fuse
        rados
        rbd
      ].each do |file|
        bin.install "bin/#{file}"
      end
      %w[
        ceph-common.2
        ceph-common
        rados.2.0.0
        rados.2
        rados
        radosstriper.1.0.0
        radosstriper.1
        radosstriper
        rbd.1.18.0
        rbd.1
        rbd
        cephfs.2.0.0
        cephfs.2
        cephfs
      ].each do |name|
        lib.install "lib/lib#{name}.dylib"
      end
      %w[
        ceph-conf
        ceph-fuse
        ceph
        librados-config
        rados
        rbd
      ].each do |name|
        man8.install "doc/man/#{name}.8"
      end
      system "ninja", "src/include/install"
    end

    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])
    %w[
      ceph-conf
      ceph-fuse
      rados
      rbd
    ].each do |name|
      system "install_name_tool", "-add_rpath", "/opt/homebrew/lib", "#{libexec}/bin/#{name}"
    end
  end

  test do
    system "#{bin}/ceph", "--version"
    system "#{bin}/rados", "--version"
    system "#{bin}/rbd", "--version"
  end
end

__END__
diff --git a/cmake/modules/Distutils.cmake b/cmake/modules/Distutils.cmake
index 9d66ae979a6..eabf22bf174 100644
--- a/cmake/modules/Distutils.cmake
+++ b/cmake/modules/Distutils.cmake
@@ -93,11 +93,9 @@ function(distutils_add_cython_module target name src)
     OUTPUT ${output_dir}/${name}${ext_suffix}
     COMMAND
     env
-    CC="${PY_CC}"
     CFLAGS="${PY_CFLAGS}"
     CPPFLAGS="${PY_CPPFLAGS}"
     CXX="${PY_CXX}"
-    LDSHARED="${PY_LDSHARED}"
     OPT=\"-DNDEBUG -g -fwrapv -O2 -w\"
     LDFLAGS=-L${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
     CYTHON_BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
@@ -125,8 +123,6 @@ function(distutils_install_cython_module name)
     set(maybe_verbose --verbose)
   endif()
   install(CODE "
-    set(ENV{CC} \"${PY_CC}\")
-    set(ENV{LDSHARED} \"${PY_LDSHARED}\")
     set(ENV{CPPFLAGS} \"-iquote${CMAKE_SOURCE_DIR}/src/include
                         -D'void0=dead_function\(void\)' \
                         -D'__Pyx_check_single_interpreter\(ARG\)=ARG\#\#0' \
@@ -135,7 +131,7 @@ function(distutils_install_cython_module name)
     set(ENV{CYTHON_BUILD_DIR} \"${CMAKE_CURRENT_BINARY_DIR}\")
     set(ENV{CEPH_LIBDIR} \"${CMAKE_LIBRARY_OUTPUT_DIRECTORY}\")

-    set(options --prefix=${CMAKE_INSTALL_PREFIX})
+    set(options --prefix=${CMAKE_INSTALL_PREFIX} --install-lib=${CMAKE_INSTALL_PREFIX}/lib/python3.11/site-packages)
     if(DEFINED ENV{DESTDIR})
       if(EXISTS /etc/debian_version)
         list(APPEND options --install-layout=deb)
--- a/cmake/modules/BuildBoost.cmake	2022-10-17 23:07:30
+++ b/cmake/modules/BuildBoost.cmake	2026-04-24 20:00:11
@@ -46,6 +46,10 @@
 endmacro()

 function(do_build_boost root_dir version)
+  if(WITH_SYSTEM_BOOST)
+    message(STATUS "Using system Boost, skipping build_boost()")
+    return()
+  endif()
   cmake_parse_arguments(Boost_BUILD "" "" COMPONENTS ${ARGN})
   set(boost_features "variant=release")
   if(Boost_USE_MULTITHREADED)
