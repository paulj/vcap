require File.expand_path('../../nginx_common/nginx', __FILE__)

class PhpPlugin < StagingPlugin
  # TODO - Is there a way to avoid this without some kind of 'register' callback?
  # e.g. StagingPlugin.register('sinatra', __FILE__)
  def framework
    'php'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      phpapp_root = Nginx.prepare(destination_directory)
      copy_source_files
      create_startup_script
    end
  end

  def start_app_template
    <<-SCRIPT
    #{start_command} > ../logs/stdout.log 2> ../logs/stderr.log &
    PHP_STARTED=$!
    NGINX_STARTED=`cat nginx_cloudfoundry/sbin/nginx.pid`
    echo "$PHP_STARTED" >> ../run.pid
    PHP_PROCESS='`pgrep -P '$PHP_STARTED'`'
    NGINX_PROCESS='`pgrep -P '$NGINX_STARTED'`'
    PROCESS='$i'
    SCRIPT
  end

  def start_command
      cmds = []
      cmds << "nginx_cloudfoundry/sbin/nginx"
      cmds << "#{php_start_command}"
      cmds.join("\n")
  end

  def php_start_command
    "PHP_FCGI_CHILDREN=5 PHP_FCGI_MAX_REQUESTS=10000 /usr/bin/php-cgi -b $HOME/php.socket"
  end

  # Nicer kill script that attempts an INT first, and then only if the process doesn't die will
  # we try a -9.
  def stop_script_template
    <<-SCRIPT
    #!/bin/bash
    for i in $PHP_PROCESS; do
      kill -9 $PHP_STARTED
      kill -9 $PROCESS
      wait $PROCESS
    done
    for i in $NGINX_PROCESS; do
      kill -9 $NGINX_STARTED
      kill -9 $PROCESS
      wait $PROCESS
    done
    kill -9 $PPID
    SCRIPT
  end

  def wait_app_template
    <<-SCRIPT
    wait $PHP_STARTED
    wait $NGINX_STARTED
    SCRIPT
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars) do
      # Nginx has no support for using environment variables in the config file. So we do it
      # for it using sed at the last minute.
      <<-SCRIPT
      cat app/nginx_cloudfoundry/conf/nginx.conf.template | \
        sed 's!VCAP_APP_PORT!'"$VCAP_APP_PORT"'!' | \
        sed 's!HOME!'"$HOME"'!' > app/nginx_cloudfoundry/conf/nginx.conf
      SCRIPT
    end
  end

end

