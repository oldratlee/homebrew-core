class Erlang < Formula
  desc "Programming language for highly scalable real-time systems"
  homepage "https://www.erlang.org/"
  # Download tarball from GitHub; it is served faster than the official tarball.
  url "https://github.com/erlang/otp/releases/download/OTP-24.2.2/otp_src_24.2.2.tar.gz"
  sha256 "a87bcbdcdd1b99de7038030123b2d655d46d6e698a9143608618bdbec6ebbee7"
  license "Apache-2.0"

  livecheck do
    url :stable
    regex(/^OTP[._-]v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_monterey: "8c00cfac0597f40aafe9bce7bce2e55d9f0fb1de9ef6dd735f0b9149a38f3073"
    sha256 cellar: :any,                 arm64_big_sur:  "6f9021d173994d8eed1a61a06ae86138672cd6f7c3f72d06e7c8cec8b63d2126"
    sha256 cellar: :any,                 monterey:       "a20417605f5978f08f7790e1917c49b33ba5617e24023d261025f1c42632a1f1"
    sha256 cellar: :any,                 big_sur:        "e04536fea731d008630a34adc3f5b13492253e056c1824ef89ca3c3e2843ae44"
    sha256 cellar: :any,                 catalina:       "09a19013f426ed51f0785a4c2818a3eff57defa50f238fffd010782ef6f03331"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "bbbc9d060ecfd5cd7c8e3ae1d5fa55f2737b1d477a19abc2e81c36b003b5b8ed"
  end

  head do
    url "https://github.com/erlang/otp.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "openssl@1.1"
  depends_on "wxwidgets" # for GUI apps like observer

  resource "html" do
    url "https://github.com/erlang/otp/releases/download/OTP-24.2.2/otp_doc_html_24.2.2.tar.gz"
    mirror "https://fossies.org/linux/misc/otp_doc_html_24.2.2.tar.gz"
    sha256 "727fe65fef1c79476663fd322b397fea17fe52734c16997226dfb9fd8453b343"
  end

  def install
    # Unset these so that building wx, kernel, compiler and
    # other modules doesn't fail with an unintelligible error.
    %w[LIBS FLAGS AFLAGS ZFLAGS].each { |k| ENV.delete("ERL_#{k}") }

    # Do this if building from a checkout to generate configure
    system "./otp_build", "autoconf" unless File.exist? "configure"

    args = %W[
      --disable-debug
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-dynamic-ssl-lib
      --enable-hipe
      --enable-shared-zlib
      --enable-smp-support
      --enable-threads
      --enable-wx
      --with-ssl=#{Formula["openssl@1.1"].opt_prefix}
      --without-javac
    ]

    if OS.mac?
      args << "--enable-darwin-64bit"
      args << "--enable-kernel-poll" if MacOS.version > :el_capitan
      args << "--with-dynamic-trace=dtrace" if MacOS::CLT.installed?
    end

    system "./configure", *args
    system "make"
    system "make", "install"

    # Build the doc chunks (manpages are also built by default)
    system "make", "docs", "DOC_TARGETS=chunks"
    system "make", "install-docs"

    doc.install resource("html")
  end

  def caveats
    <<~EOS
      Man pages can be found in:
        #{opt_lib}/erlang/man

      Access them with `erl -man`, or add this directory to MANPATH.
    EOS
  end

  test do
    system "#{bin}/erl", "-noshell", "-eval", "crypto:start().", "-s", "init", "stop"
    (testpath/"factorial").write <<~EOS
      #!#{bin}/escript
      %% -*- erlang -*-
      %%! -smp enable -sname factorial -mnesia debug verbose
      main([String]) ->
          try
              N = list_to_integer(String),
              F = fac(N),
              io:format("factorial ~w = ~w\n", [N,F])
          catch
              _:_ ->
                  usage()
          end;
      main(_) ->
          usage().

      usage() ->
          io:format("usage: factorial integer\n").

      fac(0) -> 1;
      fac(N) -> N * fac(N-1).
    EOS
    chmod 0755, "factorial"
    assert_match "usage: factorial integer", shell_output("./factorial")
    assert_match "factorial 42 = 1405006117752879898543142606244511569936384000000000", shell_output("./factorial 42")
  end
end
