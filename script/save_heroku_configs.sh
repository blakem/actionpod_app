echo "*********** heroku config --app actionpods > config/heroku_config"
heroku config --app actionpods > config/heroku_config

echo "*********** heroku info --app actionpods > config/heroku_info"
heroku info --app actionpods > config/heroku_info

echo "*********** heroku config --app actionpods-staging > config/heroku_staging_config"
heroku config --app actionpods-staging > config/heroku_staging_config

echo "*********** heroku info --app actionpods-staging > config/heroku_staging_info"
heroku info --app actionpods-staging > config/heroku_staging_info
