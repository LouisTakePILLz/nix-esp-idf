{ fetchFromGitHub }:

{
  esp-idf = rec {
    version = "4.1";
    src = fetchFromGitHub {
      owner = "espressif";
      repo = "esp-idf";
      rev = "v${version}";
      sha256 = "12m76zfdzqn6d3fipggnh72cw8a08n0f84z4kxys9bjzyd70di4p";
    };
  };
}
