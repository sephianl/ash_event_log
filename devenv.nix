{ pkgs, ... }:

{
  languages = {
    elixir = {
      enable = true;
      package = pkgs.elixir_1_19;
    };
    erlang.enable = true;
  };

  services.postgres = {
    enable = true;
    initialScript = ''
      CREATE USER postgres SUPERUSER;
      ALTER USER postgres WITH ENCRYPTED PASSWORD 'postgres';
    '';
  };

  enterTest = ''
    mix test
  '';
}
