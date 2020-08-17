# shellcheck shell=sh disable=SC2004,SC2016

Describe "getoptions()"
  Include ./getoptions.sh

  parse() {
    eval "$(getoptions parser_definition _parse)"
    case $# in
      0) _parse ;;
      *) _parse "$@" ;;
    esac
  }

  It "generates option parser"
    parser_definition() { setup ARGS; echo 'called' >&2; }
    When call parse
    The word 1 of stderr should eq "called"
    The status should be success
  End

  Describe 'get rest arguments'
    restargs() {
      parse "$@"
      eval "set -- $ARGS"
      echo "$@"
    }

    Context 'when scanning mode is default'
      It "gets rest arguments"
        parser_definition() {
          setup ARGS -- 'foo bar'
          flag FLAG_A -a
        }
        When call restargs -a 1 -a 2 -a 3 -- -a
        The variable FLAG_A should eq 1
        The output should eq "1 2 3 -a"
      End
    End

    Context 'when scanning mode is +'
      It "gets rest arguments"
        parser_definition() {
          setup ARGS mode:+ -- 'foo bar'
          flag FLAG_A -a
        }
        When call restargs -a 1 -a 2 -a 3 -- -a
        The variable FLAG_A should eq 1
        The output should eq "1 -a 2 -a 3 -- -a"
      End
    End
  End

  Describe '+option'
    restargs() {
      parse "$@"
      eval "set -- $RESTARGS"
      echo "$@"
    }

    It "treats as arguments by default"
      parser_definition() { setup RESTARGS; }
      When call restargs +o
      The output should eq "+o"
    End

    It "treats as option when specified plus:true"
      parser_definition() { setup RESTARGS plus:true; }
      When run restargs +o
      The stderr should eq "unrecognized option '+o'"
      The status should be failure
    End
  End

  Describe 'displays error message'
    Specify "when specified unknown option"
      parser_definition() { setup ARGS; }
      When run parse -x
      The stderr should eq "unrecognized option '-x'"
      The status should be failure
    End

    Specify "when specified an argument to flag"
      parser_definition() { setup ARGS; flag FLAG --flag; }
      When run parse --flag=value
      The stderr should eq "option '--flag' doesn't allow an argument"
      The status should be failure
    End

    Specify "when missing an argument for parameter"
      parser_definition() { setup ARGS; param PARAM --param; }
      When run parse --param
      The stderr should eq "option '--param' requires an argument"
      The status should be failure
    End
  End

  Context 'when custom error handler defined'
    parser_definition() {
      setup RESTARGS error:myerror
      param PARAM -p
    }
    myerror() {
      case $2 in
        unknown) echo custom "$@" ;;
        *) return 1 ;;
      esac
    }

    It "display custom error message"
      When run parse -x
      The stderr should eq "custom -x unknown"
      The status should be failure
    End

    It "display default error message when custom error hander fails"
      When run parse -p
      The stderr should eq "option '-p' requires an argument"
      The status should be failure
    End
  End

  Describe 'flag'
    It "handles flags"
      parser_definition() {
        setup ARGS
        flag FLAG_A -a
        flag FLAG_B +b
        flag FLAG_C --flag-c
        flag FLAG_D --{no-}flag-d
        flag FLAG_E --no-flag-e
        flag FLAG_F --{no-}flag-f
      }
      When call parse -a +b --flag-c --flag-d --no-flag-e --no-flag-f
      The variable FLAG_A should eq 1
      The variable FLAG_B should eq ""
      The variable FLAG_C should eq 1
      The variable FLAG_D should eq 1
      The variable FLAG_E should eq ""
      The variable FLAG_F should eq ""
    End

    It "can change the set value"
      parser_definition() {
        setup ARGS
        flag FLAG_A -a on:ON off:OFF
        flag FLAG_B +b on:ON off:OFF
      }
      When call parse -a +b
      The variable FLAG_A should eq "ON"
      The variable FLAG_B should eq "OFF"
    End

    It "set initial value when not specified flag"
      parser_definition() {
        setup ARGS
        flag FLAG_A -a on:ON off:OFF init:@on
        flag FLAG_B -b on:ON off:OFF init:@off
        flag FLAG_C -c on:ON off:OFF init:'FLAG_C=func'
        flag FLAG_D -d on:ON off:OFF
        flag FLAG_Q -q on:"a'b\""
        flag FLAG_U -u init:@unset
      }
      When call parse -q
      The variable FLAG_A should eq "ON"
      The variable FLAG_B should eq "OFF"
      The variable FLAG_C should eq "func"
      The variable FLAG_D should eq ""
      The variable FLAG_Q should eq "a'b\""
      The variable FLAG_U should be undefined
    End

    It "can be used combined short flags"
      parser_definition() {
        setup ARGS
        flag FLAG_A -a
        flag FLAG_B -b
        flag FLAG_C -c
        flag FLAG_D +d init:@on
        flag FLAG_E +e init:@on
        flag FLAG_F +f init:@on
      }
      When call parse -abc +def
      The variable FLAG_A should be present
      The variable FLAG_B should be present
      The variable FLAG_C should be present
      The variable FLAG_D should be blank
      The variable FLAG_E should be blank
      The variable FLAG_F should be blank
    End

    It "counts flags"
      parser_definition() {
        setup ARGS
        flag COUNT -c +c counter:true
      }
      When call parse -c -c -c +c -c
      The variable COUNT should eq 3
    End

    It "calls the function"
      parser_definition() {
        setup ARGS
        flag :'foo "$1"' -f on:ON
      }
      foo() { echo "called $OPTARG $1"; }
      When run parse -f
      The output should eq "called ON -f"
    End

    It "calls the validator"
      valid() { echo "$OPTARG" "$@"; }
      parser_definition() {
        setup ARGS
        flag FLAG -f +f on:ON off:OFF validate:'valid "$1"'
      }
      When call parse -f +f
      The line 1 should eq "ON -f"
      The line 2 should eq "OFF +f"
    End

    Context 'when common flag value is specified'
      parser_definition() {
        setup ARGS on:ON off:OFF
        flag FLAG_A -a
        flag FLAG_B +b
      }
      It "can change the set value"
        When call parse -a +b
        The variable FLAG_A should eq "ON"
        The variable FLAG_B should eq "OFF"
      End
    End
  End

  Describe 'param'
    It "handles parameters"
      parser_definition() {
        setup ARGS
        param PARAM_P -p
        param PARAM_Q -q
        param PARAM   --param
      }
      When call parse -p value1 -qvalue2 --param=value3
      The variable PARAM_P should eq "value1"
      The variable PARAM_Q should eq "value2"
      The variable PARAM should eq "value3"
    End

    It "remains initial value when not specified parameter"
      parser_definition() {
        setup ARGS
        param PARAM_P -p init:="initial"
      }
      When call parse
      The variable PARAM_P should eq "initial"
    End

    It "calls the function"
      parser_definition() {
        setup ARGS
        param :'foo "$1"' -p
      }
      foo() { echo "called $OPTARG $1"; }
      When run parse -p 123
      The output should eq "called 123 -p"
    End

    It "calls the validator"
      valid() { echo "$OPTARG" "$@"; }
      parser_definition() {
        setup ARGS
        param PARAM_P -p validate:'valid "$1"'
        param PARAM_Q -q validate:'valid "$1"'
        param PARAM   --param validate:'valid "$1"'
      }
      When call parse -p value1 -qvalue2 --param=value3
      The line 1 should eq "value1 -p"
      The line 2 should eq "value2 -q"
      The line 3 should eq "value3 --param"
    End
  End

  Describe 'option'
    It "handles options"
      parser_definition() {
        setup ARGS
        option OPTION_O -o default:"default"
        option OPTION_P -p
        option OPTION   --option
      }
      When call parse -o -pvalue1 --option=value2
      The variable OPTION_O should eq "default"
      The variable OPTION_P should eq "value1"
      The variable OPTION should eq "value2"
    End

    It "remains initial value when not specified parameter"
      parser_definition() {
        setup ARGS
        option OPTION_O -p init:="initial"
      }
      When call parse
      The variable OPTION_O should eq "initial"
    End

    It "calls the function"
      parser_definition() {
        setup ARGS
        option :'foo "$1"' -o
      }
      foo() { echo "called $OPTARG $1"; }
      When run parse -o123
      The output should eq "called 123 -o"
    End

    It "calls the validator"
      valid() { echo "$OPTARG" "$@"; }
      parser_definition() {
        setup ARGS
        option OPTION_O -o validate:'valid "$1"' default:"default"
        option OPTION_P -p validate:'valid "$1"'
        option OPTION   --option validate:'valid "$1"'
      }
      When call parse -o -pvalue1 --option=value2
      The line 1 should eq "default -o"
      The line 2 should eq "value1 -p"
      The line 3 should eq "value2 --option"
    End
  End

  Describe 'disp'
    BeforeRun VERSION=1.0

    It "displays the variable"
      parser_definition() {
        setup ARGS
        disp VERSION -v
      }
      When run parse -v
      The output should eq "1.0"
    End

    It "calls the function"
      version() { echo "func: $VERSION"; }
      parser_definition() {
        setup ARGS
        disp :version -v
      }
      When run parse -v
      The output should eq "func: 1.0"
    End
  End

  Describe 'msg'
    It "does nothing"
      parser_definition() {
        setup ARGS
        msg -- 'test' 'foo bar'
      }
      When run parse
      The output should be blank
    End
  End

  Describe 'alternative mode'
    It "allow long options to start with a single '-'"
      parser_definition() {
        setup ARGS alt:true
        flag FLAG --flag
        param PARAM --param
        option OPTION --option
      }
      When call parse -flag -param p -option=o
      The variable FLAG should eq 1
      The variable PARAM should eq "p"
      The variable OPTION should eq "o"
    End
  End
End

Describe "getoptions_help()"
  Include ./getoptions_help.sh

  usage() {
    eval "$(getoptions_help parser_definition _usage)"
    case $# in
      0) _usage ;;
      *) _usage "$@" ;;
    esac
  }

  It "generates usage"
    parser_definition() { echo 'usage'; }
    When call usage
    The output should eq "usage"
    The status should be success
  End

  It "displays usage"
    parser_definition() {
      setup width:20 -- 'usage'
      msg -- "header"
      flag FLAG_A -a +a --{no-}flag-a -- "flag a"
      param PARAM_P -p -- "param p"
      option OPTION_O -o -- "option o"
      msg -- "footer"
    }
    When call usage
    The line 1 should eq "usage"
    The line 2 should eq "header"
    The line 3 should eq "  -a, +a, --{no-}flag-a  "
    The line 4 should eq "                    flag a"
    The line 5 should eq "  -p PARAM_P        param p"
    The line 6 should eq "  -o [OPTION_O]     option o"
    The line 7 should eq "footer"
  End
End
