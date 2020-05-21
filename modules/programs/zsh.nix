{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.zsh;

  relToDotDir = file: (optionalString (cfg.dotDir != null) (cfg.dotDir + "/")) + file;

  pluginsDir = if cfg.dotDir != null then
    relToDotDir "plugins" else ".zsh/plugins";

  envVarsStr = config.lib.zsh.exportAll cfg.sessionVariables;
  localVarsStr = config.lib.zsh.defineAll cfg.localVariables;

  aliasesStr = concatStringsSep "\n" (
    mapAttrsToList (k: v: "alias ${k}=${lib.escapeShellArg v}") cfg.shellAliases
  );

  globalAliasesStr = concatStringsSep "\n" (
    mapAttrsToList (k: v: "alias -g ${k}=${lib.escapeShellArg v}") cfg.shellGlobalAliases
  );

  zdotdir = "$HOME/" + cfg.dotDir;

  bindkeyCommands = {
    emacs = "bindkey -e";
    viins = "bindkey -v";
    vicmd = "bindkey -a";
  };

  stateVersion = config.home.stateVersion;

  historyModule = types.submodule ({ config, ... }: {
    options = {
      size = mkOption {
        type = types.int;
        default = 10000;
        description = "Number of history lines to keep.";
      };

      save = mkOption {
        type = types.int;
        defaultText = 10000;
        default = config.size;
        description = "Number of history lines to save.";
      };

      path = mkOption {
        type = types.str;
        default = if versionAtLeast stateVersion "20.03"
          then "$HOME/.zsh_history"
          else relToDotDir ".zsh_history";
        example = literalExample ''"''${config.xdg.dataHome}/zsh/zsh_history"'';
        description = "History file location";
      };

      ignoreDups = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Do not enter command lines into the history list
          if they are duplicates of the previous event.
        '';
      };

      ignoreSpace = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Do not enter command lines into the history list
          if the first character is a space.
        '';
      };

      expireDuplicatesFirst = mkOption {
        type = types.bool;
        default = false;
        description = "Expire duplicates first.";
      };

      extended = mkOption {
        type = types.bool;
        default = false;
        description = "Save timestamp into the history file.";
      };

      share = mkOption {
        type = types.bool;
        default = true;
        description = "Share command history between zsh sessions.";
      };
    };
  });

  pluginModule = types.submodule ({ config, ... }: {
    options = {
      src = mkOption {
        type = types.path;
        description = ''
          Path to the plugin folder.

          Will be added to <envar>fpath</envar> and <envar>PATH</envar>.
        '';
      };

      name = mkOption {
        type = types.str;
        description = ''
          The name of the plugin.

          Don't forget to add <option>file</option>
          if the script name does not follow convention.
        '';
      };

      file = mkOption {
        type = types.str;
        description = "The plugin script to source.";
      };
    };

    config.file = mkDefault "${config.name}.plugin.zsh";
  });

  ohMyZshModule = types.submodule {
    options = {
      enable = mkEnableOption "oh-my-zsh";

      plugins = mkOption {
        default = [];
        example = [ "git" "sudo" ];
        type = types.listOf types.str;
        description = ''
          List of oh-my-zsh plugins
        '';
      };

      custom = mkOption {
        default = "";
        type = types.str;
        example = "$HOME/my_customizations";
        description = ''
          Path to a custom oh-my-zsh package to override config of
          oh-my-zsh. See <link xlink:href="https://github.com/robbyrussell/oh-my-zsh/wiki/Customization"/>
          for more information.
        '';
      };

      theme = mkOption {
        default = "";
        example = "robbyrussell";
        type = types.str;
        description = ''
          Name of the theme to be used by oh-my-zsh.
        '';
      };

      extraConfig = mkOption {
        default = "";
        example = ''
          zstyle :omz:plugins:ssh-agent identities id_rsa id_rsa2 id_github
        '';
        type = types.lines;
        description = ''
          Extra settings for plugins.
        '';
      };
    };
  };

  preztoModule = types.submodule {
    options = {
      enable = mkEnableOption "prezto";

      caseSensitive = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = "Set case-sensitivity for completion, history lookup, etc.";
      };

      color = mkOption {
        type = types.nullOr types.bool;
        default = true;
        example = false;
        description = "Color output (auto set to 'no' on dumb terminals)";
      };

      pmoduleDirs = mkOption {
        type = types.listOf types.path;
        default = [];
        example = [ "$HOME/.zprezto-contrib" ];
        description = "Add additional directories to load prezto modules from";
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Additional configuration to add to <filename>.zpreztorc</filename>.
        '';
      };

      extraModules = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "attr" "stat" ];
        description = "Set the Zsh modules to load (man zshmodules).";
      };

      extraFunctions = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "zargs" "zmv" ];
        description = "Set the Zsh functions to load (man zshcontrib).";
      };

      pmodules = mkOption {
        type = types.listOf types.str;
        default = [ "environment" "terminal" "editor" "history" "directory" "spectrum" "utility" "completion" "prompt" ];
        description = "Set the Prezto modules to load (browse modules). The order matters.";
      };

      autosuggestions.color = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "fg=blue";
        description = "Set the query found color.";
      };

      completions.ignoredHosts = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "0.0.0.0" "127.0.0.1" ];
        description = "Set the entries to ignore in static */etc/hosts* for host completion.";
      };

      editor = {
        keymap = mkOption {
          type = types.nullOr (types.enum ["emacs" "vi"]);
          default = "emacs";
          example = "vi";
          description = "Set the key mapping style to 'emacs' or 'vi'.";
        };

        dotExpansion = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Auto convert .... to ../..";
        };

        promptContext = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Allow the zsh prompt context to be shown.";
        };
      };

      git.submoduleIgnore = mkOption {
        type = types.nullOr (types.enum ["dirty" "untracked" "all" "none"]);
        default = null;
        example = "all";
        description = "Ignore submodules when they are 'dirty', 'untracked', 'all', or 'none'.";
      };

      gnuUtility.prefix = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "g";
        description = "Set the command prefix on non-GNU systems.";
      };

      historySubstring = {
        foundColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "fg=blue";
          description = "Set the query found color.";
        };

        notFoundColor = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "fg=red";
          description = "Set the query not found color.";
        };

        globbingFlags = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Set the search globbing flags.";
        };
      };

      macOS.dashKeyword = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "manpages";
        description = "Set the keyword used by `mand` to open man pages in Dash.app";
      };

      prompt = {
        theme = mkOption {
          type = types.nullOr types.str;
          default = "sorin";
          example = "pure";
          description = "Set the prompt theme to load. Setting it to 'random'
          loads a random theme. Auto set to 'off' on dumb terminals.";
        };

        pwdLength = mkOption {
          type = types.nullOr (types.enum ["short" "long" "full"]);
          default = null;
          example = "short";
          description = "Set the working directory prompt display length. By
          default, it is set to 'short'. Set it to 'long' (without '~' expansion) for
          longer or 'full' (with '~' expansion) for even longer prompt display.";
        };

        showReturnVal = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Set the prompt to display the return code along with an
          indicator for non-zero return codes. This is not supported by all prompts.";
        };
      };

      python = {
        virtualenvAutoSwitch = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Auto switch to Python virtualenv on directory change.";
        };

        virtualenvInitialize = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Automatically initialize virtualenvwrapper if pre-requisites are met.";
        };
      };

      ruby.chrubyAutoSwitch = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = "Auto switch the Ruby version on directory change.";
      };

      screen = {
        autoStartLocal = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Auto start a session when Zsh is launched in a local terminal.";
        };

        autoStartRemote = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Auto start a session when Zsh is launched in a SSH connection.";
        };
      };

      ssh.identities = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "id_rsa" "id_rsa2" "id_github" ];
        description = "Set the SSH identities to load into the agent.";
      };

      syntaxHighlighting = {
        highlighters = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "main" "brackets" "pattern" "line" "cursor" "root" ];
          description = "Set syntax highlighters. By default, only the main
          highlighter is enabled.";
        };

        styles = mkOption {
          type = types.attrsOf types.str;
          default = {};
          example = { builtin = "bg=blue"; command = "bg=blue"; function = "bg=blue"; };
          description = "Set syntax highlighting styles.";
        };

        pattern = mkOption {
          type = types.attrsOf types.str;
          default = {};
          example = { "rm*-rf*" = "fg=white,bold,bg=red"; };
          description = "Set syntax pattern styles.";
        };
      };

      terminal = {
        autoTitle = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Auto set the tab and window titles.";
        };

        windowTitleFormat = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "%n@%m: %s";
          description = "Set the window title format.";
        };

        tabTitleFormat = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "%m: %s";
          description = "Set the tab title format.";
        };

        multiplexerTitleFormat = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "%s";
          description = "Set the multiplexer title format.";
        };
      };

      tmux = {
        autoStartLocal = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Auto start a session when Zsh is launched in a local terminal.";
        };

        autoStartRemote = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Auto start a session when Zsh is launched in a SSH connection.";
        };

        itermIntegration = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Integrate with iTerm2.";
        };

        defaultSessionName = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "YOUR DEFAULT SESSION NAME";
          description = "Set the default session name.";
        };
      };

      utility.safeOps = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = "Enabled safe options. This aliases cp, ln, mv and rm so
        that they prompt before deleting or overwriting files. Set to 'no' to disable
        this safer behavior.";
      };
    };
  };

in

{
  options = {
    programs.zsh = {
      enable = mkEnableOption "Z shell (Zsh)";

      autocd = mkOption {
        default = null;
        description = ''
          Automatically enter into a directory if typed directly into shell.
        '';
        type = types.nullOr types.bool;
      };

      cdpath = mkOption {
        default = [];
        description = ''
          List of paths to autocomplete calls to `cd`.
        '';
        type = types.listOf types.str;
      };

      dotDir = mkOption {
        default = null;
        example = ".config/zsh";
        description = ''
          Directory where the zsh configuration and more should be located,
          relative to the users home directory. The default is the home
          directory.
        '';
        type = types.nullOr types.str;
      };

      shellAliases = mkOption {
        default = {};
        example = literalExample ''
          {
            ll = "ls -l";
            ".." = "cd ..";
          }
        '';
        description = ''
          An attribute set that maps aliases (the top level attribute names in
          this option) to command strings or directly to build outputs.
        '';
        type = types.attrsOf types.str;
      };

      shellGlobalAliases = mkOption {
        default = {};
        example = literalExample ''
          {
            UUID = "$(uuidgen | tr -d \\n)";
            G = "| grep";
          }
        '';
        description = ''
          Similar to <varname><link linkend="opt-programs.zsh.shellAliases">opt-programs.zsh.shellAliases</link></varname>,
          but are substituted anywhere on a line.
        '';
        type = types.attrsOf types.str;
      };

      enableCompletion = mkOption {
        default = true;
        description = ''
          Enable zsh completion. Don't forget to add
          <programlisting language="nix">
            environment.pathsToLink = [ "/share/zsh" ];
          </programlisting>
          to your system configuration to get completion for system packages (e.g. systemd).
        '';
        type = types.bool;
      };

      enableAutosuggestions = mkOption {
        default = false;
        description = "Enable zsh autosuggestions";
      };

      history = mkOption {
        type = historyModule;
        default = {};
        description = "Options related to commands history configuration.";
      };

      defaultKeymap = mkOption {
        type = types.nullOr (types.enum (attrNames bindkeyCommands));
        default = null;
        example = "emacs";
        description = "The default base keymap to use.";
      };

      sessionVariables = mkOption {
        default = {};
        type = types.attrs;
        example = { MAILCHECK = 30; };
        description = "Environment variables that will be set for zsh session.";
      };

      initExtraBeforeCompInit = mkOption {
        default = "";
        type = types.lines;
        description = "Extra commands that should be added to <filename>.zshrc</filename> before compinit.";
      };

      initExtra = mkOption {
        default = "";
        type = types.lines;
        description = "Extra commands that should be added to <filename>.zshrc</filename>.";
      };

      envExtra = mkOption {
        default = "";
        type = types.lines;
        description = "Extra commands that should be added to <filename>.zshenv</filename>.";
      };

      profileExtra = mkOption {
        default = "";
        type = types.lines;
        description = "Extra commands that should be added to <filename>.zprofile</filename>.";
      };

      loginExtra = mkOption {
        default = "";
        type = types.lines;
        description = "Extra commands that should be added to <filename>.zlogin</filename>.";
      };

      logoutExtra = mkOption {
        default = "";
        type = types.lines;
        description = "Extra commands that should be added to <filename>.zlogout</filename>.";
      };

      plugins = mkOption {
        type = types.listOf pluginModule;
        default = [];
        example = literalExample ''
          [
            {
              # will source zsh-autosuggestions.plugin.zsh
              name = "zsh-autosuggestions";
              src = pkgs.fetchFromGitHub {
                owner = "zsh-users";
                repo = "zsh-autosuggestions";
                rev = "v0.4.0";
                sha256 = "0z6i9wjjklb4lvr7zjhbphibsyx51psv50gm07mbb0kj9058j6kc";
              };
            }
            {
              name = "enhancd";
              file = "init.sh";
              src = pkgs.fetchFromGitHub {
                owner = "b4b4r07";
                repo = "enhancd";
                rev = "v2.2.1";
                sha256 = "0iqa9j09fwm6nj5rpip87x3hnvbbz9w9ajgm6wkrd5fls8fn8i5g";
              };
            }
          ]
        '';
        description = "Plugins to source in <filename>.zshrc</filename>.";
      };

      oh-my-zsh = mkOption {
        type = ohMyZshModule;
        default = {};
        description = "Options to configure oh-my-zsh.";
      };

      prezto = mkOption {
        type = preztoModule;
        default = {};
        description = "Options to configure prezto.";
      };

      localVariables = mkOption {
        type = types.attrs;
        default = {};
        example = { POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=["dir" "vcs"]; };
        description = ''
          Extra local variables defined at the top of <filename>.zshrc</filename>.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.envExtra != "") {
      home.file."${relToDotDir ".zshenv"}".text = cfg.envExtra;
    })

    (mkIf (cfg.profileExtra != "") {
      home.file."${relToDotDir ".zprofile"}".text =
        optionalString cfg.prezto.enable
        (builtins.readFile "${pkgs.zsh-prezto}/runcoms/zprofile")
        + cfg.profileExtra;
    })

    (mkIf (cfg.prezto.enable && cfg.profileExtra == "") {
      home.file."${relToDotDir ".zprofile"}".source =
        "${pkgs.zsh-prezto}/runcoms/zprofile";
    })

    (mkIf (cfg.loginExtra != "") {
      home.file."${relToDotDir ".zlogin"}".text =
        optionalString cfg.prezto.enable
        (builtins.readFile "${pkgs.zsh-prezto}/runcoms/zlogin")
        + cfg.loginExtra;
    })

    (mkIf (cfg.prezto.enable && cfg.loginExtra == "") {
      home.file."${relToDotDir ".zlogin"}".source =
        "${pkgs.zsh-prezto}/runcoms/zlogin";
    })

    (mkIf (cfg.logoutExtra != "") {
      home.file."${relToDotDir ".zlogout"}".text =
        optionalString cfg.prezto.enable
        (builtins.readFile "${pkgs.zsh-prezto}/runcoms/zlogout")
        + cfg.logoutExtra;
    })

    (mkIf (cfg.prezto.enable && cfg.logoutExtra == "") {
      home.file."${relToDotDir ".zlogout"}".source =
        "${pkgs.zsh-prezto}/runcoms/zlogout";
    })

    (mkIf cfg.oh-my-zsh.enable {
      home.file."${relToDotDir ".zshenv"}".text = ''
        ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh";
        ZSH_CACHE_DIR="${config.xdg.cacheHome}/oh-my-zsh";
      '';
    })

    (mkIf cfg.prezto.enable {
      home.file."${relToDotDir ".zshenv"}".text =
        (builtins.readFile "${pkgs.zsh-prezto}/runcoms/zshenv");
      home.file."${relToDotDir ".zpreztorc"}".text = ''
        # Generated by Nix
        ${optionalString (cfg.prezto.caseSensitive != null) ''
          zstyle ':prezto:*:*' case-sensitive '${if cfg.prezto.caseSensitive then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.color != null) ''
          zstyle ':prezto:*:*' color '${if cfg.prezto.color then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.pmoduleDirs != []) ''
          zstyle ':prezto:load' pmodule-dirs ${builtins.concatStringsSep " " cfg.prezto.pmoduleDirs}
        ''}
        ${optionalString (cfg.prezto.extraModules != []) ''
          zstyle ':prezto:load' zmodule ${strings.concatMapStringsSep " " strings.escapeShellArg cfg.prezto.extraModules}
        ''}
        ${optionalString (cfg.prezto.extraFunctions != []) ''
          zstyle ':prezto:load' zfunction ${strings.concatMapStringsSep " " strings.escapeShellArg cfg.prezto.extraFunctions}
        ''}
        ${optionalString (cfg.prezto.pmodules != []) ''
          zstyle ':prezto:load' pmodule \
            ${strings.concatMapStringsSep " \\\n  " strings.escapeShellArg cfg.prezto.pmodules}
        ''}
        ${optionalString (cfg.prezto.autosuggestions.color != null) ''
          zstyle ':prezto:module:autosuggestions:color' found '${cfg.prezto.autosuggestions.color}'
        ''}
        ${optionalString (cfg.prezto.completions.ignoredHosts != []) ''
          zstyle ':prezto:module:completion:*:hosts' etc-host-ignores \
            ${strings.concatMapStringsSep " " strings.escapeShellArg cfg.prezto.completions.ignoredHosts}
        ''}
        ${optionalString (cfg.prezto.editor.keymap != null) ''
          zstyle ':prezto:module:editor' key-bindings '${cfg.prezto.editor.keymap}'
        ''}
        ${optionalString (cfg.prezto.editor.dotExpansion != null) ''
          zstyle ':prezto:module:editor' dot-expansion '${if cfg.prezto.editor.dotExpansion then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.editor.promptContext != null) ''
          zstyle ':prezto:module:editor' ps-context '${if cfg.prezto.editor.promptContext then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.git.submoduleIgnore != null) ''
          zstyle ':prezto:module:git:status:ignore' submodules '${cfg.prezto.git.submoduleIgnore}'
        ''}
        ${optionalString (cfg.prezto.gnuUtility.prefix != null) ''
          zstyle ':prezto:module:gnu-utility' prefix '${cfg.prezto.gnuUtility.prefix}'
        ''}
        ${optionalString (cfg.prezto.historySubstring.foundColor != null) ''
          zstyle ':prezto:module:history-substring-search:color' found '${cfg.prezto.historySubstring.foundColor}'
        ''}
        ${optionalString (cfg.prezto.historySubstring.notFoundColor != null) ''
          zstyle ':prezto:module:history-substring-search:color' not-found '${cfg.prezto.historySubstring.notFoundColor}'
        ''}
        ${optionalString (cfg.prezto.historySubstring.globbingFlags != null) ''
          zstyle ':prezto:module:history-substring-search:color' globbing-flags '${cfg.prezto.historySubstring.globbingFlags}'
        ''}
        ${optionalString (cfg.prezto.macOS.dashKeyword != null) ''
          zstyle ':prezto:module:osx:man' dash-keyword '${cfg.prezto.macOS.dashKeyword}'
        ''}
        ${optionalString (cfg.prezto.prompt.theme != null) ''
          zstyle ':prezto:module:prompt' theme '${cfg.prezto.prompt.theme}'
        ''}
        ${optionalString (cfg.prezto.prompt.pwdLength != null) ''
          zstyle ':prezto:module:prompt' pwd-length '${cfg.prezto.prompt.pwdLength}'
        ''}
        ${optionalString (cfg.prezto.prompt.showReturnVal != null) ''
          zstyle ':prezto:module:prompt' show-return-val '${cfg.prezto.prompt.showReturnVal}'
        ''}
        ${optionalString (cfg.prezto.python.virtualenvAutoSwitch != null) ''
          zstyle ':prezto:module:python:virtualenv' auto-switch '${if cfg.prezto.python.virtualenvAutoSwitch then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.python.virtualenvInitialize != null) ''
          zstyle ':prezto:module:python:virtualenv' initialize '${if cfg.prezto.python.virtualenvInitialize then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.ruby.chrubyAutoSwitch != null) ''
          zstyle ':prezto:module:ruby:chruby' auto-switch '${if cfg.prezto.ruby.chrubyAutoSwitch then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.screen.autoStartLocal != null) ''
          zstyle ':prezto:module:screen:auto-start' local '${if cfg.prezto.screen.autoStartLocal then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.screen.autoStartRemote != null) ''
          zstyle ':prezto:module:screen:auto-start' remote '${if cfg.prezto.screen.autoStartRemote then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.ssh.identities != []) ''
          zstyle ':prezto:module:ssh:load' identities \
            ${strings.concatMapStringsSep " " strings.escapeShellArg cfg.prezto.ssh.identities}
        ''}
        ${optionalString (cfg.prezto.syntaxHighlighting.highlighters != []) ''
          zstyle ':prezto:module:syntax-highlighting' highlighters \
            ${strings.concatMapStringsSep " \\\n  " strings.escapeShellArg cfg.prezto.syntaxHighlighting.highlighters}
        ''}
        ${optionalString (cfg.prezto.syntaxHighlighting.styles != {}) ''
          zstyle ':prezto:module:syntax-highlighting' styles \
            ${ builtins.concatStringsSep " \\\n"
                (attrsets.mapAttrsToList
                  (k: v: strings.escapeShellArg k + " " + strings.escapeShellArg v)
                  cfg.prezto.syntaxHighlighting.styles)
             }
        ''}
        ${optionalString (cfg.prezto.syntaxHighlighting.pattern != {}) ''
          zstyle ':prezto:module:syntax-highlighting' pattern \
            ${ builtins.concatStringsSep " \\\n"
                (attrsets.mapAttrsToList
                  (k: v: strings.escapeShellArg k + " " + strings.escapeShellArg v)
                  cfg.prezto.syntaxHighlighting.pattern)
             }
        ''}
        ${optionalString (cfg.prezto.terminal.autoTitle != null) ''
          zstyle ':prezto:module:terminal' auto-title '${if cfg.prezto.terminal.autoTitle then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.terminal.windowTitleFormat != null) ''
          zstyle ':prezto:module:terminal:window-title' format '${cfg.prezto.terminal.windowTitleFormat}'
        ''}
        ${optionalString (cfg.prezto.terminal.tabTitleFormat != null) ''
          zstyle ':prezto:module:terminal:tab-title' format '${cfg.prezto.terminal.tabTitleFormat}'
        ''}
        ${optionalString (cfg.prezto.terminal.multiplexerTitleFormat != null) ''
          zstyle ':prezto:module:terminal:multiplexer-title' format '${cfg.prezto.terminal.multiplexerTitleFormat}'
        ''}
        ${optionalString (cfg.prezto.tmux.autoStartLocal != null) ''
          zstyle ':prezto:module:tmux:auto-start' local '${if cfg.prezto.tmux.autoStartLocal then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.tmux.autoStartRemote != null) ''
          zstyle ':prezto:module:tmux:auto-start' remote '${if cfg.prezto.tmux.autoStartRemote then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.tmux.itermIntegration != null) ''
          zstyle ':prezto:module:tmux:iterm' integrate '${if cfg.prezto.tmux.itermIntegration then "yes" else "no"}'
        ''}
        ${optionalString (cfg.prezto.tmux.defaultSessionName != null) ''
          zstyle ':prezto:module:tmux:session' name '${cfg.prezto.tmux.defaultSessionName}'
        ''}
        ${optionalString (cfg.prezto.utility.safeOps != null) ''
          zstyle ':prezto:module:utility' safe-ops '${if cfg.prezto.utility.safeOps then "yes" else "no"}'
        ''}
        ${cfg.prezto.extraConfig}
      '';
    })

    (mkIf (cfg.dotDir != null) {
      home.file."${relToDotDir ".zshenv"}".text = ''
        ZDOTDIR=${zdotdir}
      '';

      # When dotDir is set, only use ~/.zshenv to source ZDOTDIR/.zshenv,
      # This is so that if ZDOTDIR happens to be
      # already set correctly (by e.g. spawning a zsh inside a zsh), all env
      # vars still get exported
      home.file.".zshenv".text = ''
        source ${zdotdir}/.zshenv
      '';
    })

    {
      home.packages = with pkgs; [ zsh ]
        ++ optional cfg.enableCompletion nix-zsh-completions
        ++ optional cfg.oh-my-zsh.enable oh-my-zsh
        ++ optional cfg.prezto.enable zsh-prezto;

      home.file."${relToDotDir ".zshrc"}".text = ''
        typeset -U path cdpath fpath manpath

        ${optionalString (cfg.cdpath != []) ''
          cdpath+=(${concatStringsSep " " cfg.cdpath})
        ''}

        for profile in ''${(z)NIX_PROFILES}; do
          fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
        done

        HELPDIR="${pkgs.zsh}/share/zsh/$ZSH_VERSION/help"

        ${optionalString (cfg.defaultKeymap != null) ''
          # Use ${cfg.defaultKeymap} keymap as the default.
          ${getAttr cfg.defaultKeymap bindkeyCommands}
        ''}

        ${localVarsStr}

        ${cfg.initExtraBeforeCompInit}

        ${concatStrings (map (plugin: ''
          path+="$HOME/${pluginsDir}/${plugin.name}"
          fpath+="$HOME/${pluginsDir}/${plugin.name}"
        '') cfg.plugins)}

        # Oh-My-Zsh/Prezto calls compinit during initialization,
        # calling it twice causes sight start up slowdown
        # as all $fpath entries will be traversed again.
        ${optionalString (cfg.enableCompletion && !cfg.oh-my-zsh.enable && !cfg.prezto.enable)
          "autoload -U compinit && compinit"
        }

        ${optionalString cfg.enableAutosuggestions
          "source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        }

        # Environment variables
        . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
        ${envVarsStr}

        ${optionalString cfg.oh-my-zsh.enable ''
            # oh-my-zsh extra settings for plugins
            ${cfg.oh-my-zsh.extraConfig}
            # oh-my-zsh configuration generated by NixOS
            ${optionalString (cfg.oh-my-zsh.plugins != [])
              "plugins=(${concatStringsSep " " cfg.oh-my-zsh.plugins})"
            }
            ${optionalString (cfg.oh-my-zsh.custom != "")
              "ZSH_CUSTOM=\"${cfg.oh-my-zsh.custom}\""
            }
            ${optionalString (cfg.oh-my-zsh.theme != "")
              "ZSH_THEME=\"${cfg.oh-my-zsh.theme}\""
            }
            source $ZSH/oh-my-zsh.sh
        ''}

        ${optionalString cfg.prezto.enable
            (builtins.readFile "${pkgs.zsh-prezto}/runcoms/zshrc")}

        ${concatStrings (map (plugin: ''
          if [ -f "$HOME/${pluginsDir}/${plugin.name}/${plugin.file}" ]; then
            source "$HOME/${pluginsDir}/${plugin.name}/${plugin.file}"
          fi
        '') cfg.plugins)}

        # History options should be set in .zshrc and after oh-my-zsh sourcing.
        # See https://github.com/rycee/home-manager/issues/177.
        HISTSIZE="${toString cfg.history.size}"
        SAVEHIST="${toString cfg.history.save}"
        ${if versionAtLeast config.home.stateVersion "20.03"
          then ''HISTFILE="${cfg.history.path}"''
          else ''HISTFILE="$HOME/${cfg.history.path}"''}
        mkdir -p "$(dirname "$HISTFILE")"

        setopt HIST_FCNTL_LOCK
        ${if cfg.history.ignoreDups then "setopt" else "unsetopt"} HIST_IGNORE_DUPS
        ${if cfg.history.ignoreSpace then "setopt" else "unsetopt"} HIST_IGNORE_SPACE
        ${if cfg.history.expireDuplicatesFirst then "setopt" else "unsetopt"} HIST_EXPIRE_DUPS_FIRST
        ${if cfg.history.share then "setopt" else "unsetopt"} SHARE_HISTORY
        ${if cfg.history.extended then "setopt" else "unsetopt"} EXTENDED_HISTORY
        ${if cfg.autocd != null then "${if cfg.autocd then "setopt" else "unsetopt"} autocd" else ""}

        ${cfg.initExtra}

        # Aliases
        ${aliasesStr}

        # Global Aliases
        ${globalAliasesStr}
      '';
    }

    (mkIf cfg.oh-my-zsh.enable {
      # Make sure we create a cache directory since some plugins expect it to exist
      # See: https://github.com/rycee/home-manager/issues/761
      home.file."${config.xdg.cacheHome}/oh-my-zsh/.keep".text = "";
    })

    (mkIf (cfg.plugins != []) {
      # Many plugins require compinit to be called
      # but allow the user to opt out.
      programs.zsh.enableCompletion = mkDefault true;

      home.file =
        foldl' (a: b: a // b) {}
        (map (plugin: { "${pluginsDir}/${plugin.name}".source = plugin.src; })
        cfg.plugins);
    })
  ]);
}
