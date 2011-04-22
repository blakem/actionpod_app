echo "*********** heroku config --app actionpods > config/heroku/heroku_config"
heroku config --app actionpods > config/heroku/heroku_config

echo "*********** heroku info --app actionpods > config/heroku/heroku_info"
heroku info --app actionpods > config/heroku/heroku_info

echo "*********** heroku config --app actionpods-staging > config/heroku/heroku_staging_config"
heroku config --app actionpods-staging > config/heroku/heroku_staging_config

echo "*********** heroku info --app actionpods-staging > config/heroku/heroku_staging_info"
heroku info --app actionpods-staging > config/heroku/heroku_staging_info
