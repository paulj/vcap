class PhpPlugin < StagingPlugin
  # TODO - Is there a way to avoid this without some kind of 'register' callback?
  # e.g. StagingPlugin.register('sinatra', __FILE__)
  def framework
    'php'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
      create_nginx_config
    end
  end

  def start_app_template
    <<-SCRIPT
    <%= nginx_start_command %> > ../logs/stdout.log 2> ../logs/stderr.log &
    NGINX_STARTED=$!
    echo "$NGINX_STARTED" >> ../run.pid
    <%= php_start_command %> >> ../logs/stdout.log 2>> ../logs/stderr.log &
    PHP_STARTED=$!
    SCRIPT
  end

  def nginx_start_command
    # We don't pass through $@, since Nginx accepts essentially no useful argument
    "nginx -c ../nginx.config"
  end
  
  def php_start_command
    "PHP_FCGI_CHILDREN=0 PHP_FCGI_MAX_REQUESTS=10000 /usr/bin/php-cgi -b $HOME/php.socket"
  end

  # Nicer kill script that attempts an INT first, and then only if the process doesn't die will
  # we try a -9.
  def stop_script_template
    <<-SCRIPT
    #!/bin/bash
    kill -9 $NGINX_STARTED
    kill -9 $PHP_STARTED 
    kill -9 $PPID
    SCRIPT
  end

  def wait_app_template
    <<-SCRIPT
    wait $NGINX_STARTED $PHP_STARTED
    SCRIPT
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars) do
      # Nginx has no support for using environment variables in the config file. So we do it
      # for it using sed at the last minute.
      <<-SCRIPT
      cat nginx.config.template | \
        sed 's!ENV_VMC_APP_PORT!'"$VMC_APP_PORT"'!' | \
        sed 's!ENV_PWD!'"$PWD"'!' | \
        sed 's!ENV_HOME!'"$HOME"'!' >nginx.config
      SCRIPT
    end
  end

  def create_nginx_config
    File.open('nginx.config.template', 'w') do |f|
      f.write <<-EOT
      daemon off;
      
      error_log ../logs/app.error.log;
      
      http {
        include    /etc/nginx/mime.types;
        
        sendfile     on;
        tcp_nopush   on;
        
        server {
            listen       ENV_VMC_APP_PORT;
            server_name  _;
            access_log   ../logs/app.access.log  main;
            root         ENV_PWD;

            location / {
              index    index.html index.htm index.php;
            }

            location ~ \.php$ {
              include /etc/nginx/fastcgi_params;
              fastcgi_pass  unix:ENV_HOME/php.socket;
            }
          }
        }
      EOT
    end
  end
end

