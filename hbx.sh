#!/bin/bash

function __bash () {
  current_app=$(__hbx_context)
  container_name=$1
  deploy_name=$2
  kubectl exec -it -n ${current_app} deploy/${deploy_name} -c ${container_name} -- bash
}

function __rails_console () {
  current_app=$(__hbx_context)
  container_name=$1
  deploy_name=$2
  kubectl exec -it -n ${current_app} deploy/${deploy_name} -c ${container_name} -- bash -c "DISABLE_SPRING=true rails console"
}

function __tilt_up () {
  if __tilt_is_running > /dev/null; then
    echo "Tilt is already running"
  elif [ ! -f Tiltfile ]; then
    echo "Not in a folder with a Tiltfile"
  else
    screen -L -Logfile /tmp/tilt_screen.log -dmS tilt_screen zsh -c 'tilt up --stream; exec bash'
    echo "~~ Tilt started in background ~~"
    echo "$ hbx tilt logs => view output"
    echo "$ hbx tilt ui   => open UI"
  fi
}

function __tilt_halt () {
  if __tilt_is_running > /dev/null; then
    pkill tilt
    screen -S tilt_screen -X quit
    echo "Tilt halted"
  else
    echo "Tilt is not running"
  fi
}

function __tilt_down () {
  __tilt_halt
  screen -L -Logfile /tmp/tilt_screen.log -dmS tilt_screen zsh -c 'tilt down; exec bash'
  rm /tmp/tilt_screen.log
  echo "Tilt down started"
}

function __tilt_logs () {
  tail -f /tmp/tilt_screen.log
}

function __tilt_status () {
  if __tilt_is_running > /dev/null; then
    if screen -list | grep -q "tilt_screen"; then
      echo "Tilt is running inside of Screen"
    else
      echo "Tilt is running in the foreground"
    fi
  else
    echo "Tilt is not running"
  fi
}

function __tilt_is_running () {
  pgrep tilt
}

function __tilt_ui () {
  open http://localhost:10350
}

function __hbx_context () {
  if [ ! -f ~/.hbx_context ]
  then
    echo "HBX app context not set. Defaulting to Hubble."
    touch ~/.hbx_context
    echo "hubble" > ~/.hbx_context
  fi

  echo $(cat ~/.hbx_context)
}

function __set_hbx_context () {
  target_app=$1
  echo $1 > ~/.hbx_context
  echo "HBX context updated to ${target_app}"
}

function __logs () {
  container_name=$1
  deploy_name=$2
  current_app=$(__hbx_context)

  kubectl logs -f -n ${current_app} -c ${container_name} deploy/${deploy_name}
}

function __selenium_ui () {
  host=$(kubectl get ingresses -n selenium-grid -o jsonpath='{range .items[*]}{.metadata.name}│ {.metadata.namespace} {.spec.rules[*].host}{"\n"}{end}'| awk "{print \$3}")
  open "https://${host}"
}

function __delete_pod () {
  current_app=$(__hbx_context)

  kubectl delete pod -n ${current_app} -l component=${pod_name}
}

function __help () {
  cat << EOF
usage:

context
context       [ set ]
tilt          [ up | down | halt | logs | ui | status ]
rails         [ bash | console | logs | restart ]
sidekiq       [ bash | console | log ]
vue           [ bash | logs | restart ]
angular       [ bash | logs | restart ]
angular-admin [ bash | logs ]
selenium      [ ui ]
EOF
}

function hbx () {
  current_app=$(__hbx_context)
  full_cmd=$(echo "${1} ${2}" | xargs)

  case $full_cmd in
    "help")               __help
      ;;
    "context")            echo "Current app context: ${current_app}"
      ;;
    "context set")        __set_hbx_context $3
      ;;
    "tilt up")            __tilt_up
      ;;
    "tilt down")          __tilt_down
      ;;
    "tilt halt")          __tilt_halt
      ;;
    "tilt logs")          __tilt_logs
      ;;
    "tilt ui")            __tilt_ui
      ;;
    "tilt status")        __tilt_status
      ;;
    "rails bash")         __bash web web
      ;;
    "rails console")      __rails_console web web
      ;;
    "rails logs")         __logs web web
      ;;
    "rails restart")      __delete_pod web
      ;;
    "sidekiq bash")       __bash sidekiq-default sidekiq
      ;;
    "sidekiq console")    __rails_console sidekiq-default sidekiq
      ;;
    "sidekiq logs")       __logs sidekiq-default sidekiq
      ;;
    "vue bash")           __bash vue vue
      ;;
    "vue logs")           __logs vue vue
      ;;
    "vue restart")        __delete_pod vue
      ;;
    "angular bash")       __bash angularjs angularjs
      ;;
    "angular logs")       __logs angularjs angularjs
      ;;
    "angular restart")    __delete_pod angularjs
      ;;
    "angular-admin bash") __bash angularjs-admin angularjs-admin
      ;;
    "angular-admin logs") __logs angularjs-admin angularjs-admin
      ;;
    "selenium ui")        __selenium_ui
      ;;
    *)                    echo "Unknown hbx command"
      ;;
  esac
}

hbx "$@"
