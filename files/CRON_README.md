# Cron jobs

If the `~/bin/cron_daily.sh` or `~/bin/cron_hourly.sh` files exist then they will
be run and if they produce any output then it will be sent via email to the
address in the `~/.forward` file.

To avoid getting a lot of email from cron best write any scripts so they only
output any messages if something goes wrong.

## Daily

If the `~/bin/cron_daily.sh` file exists then it will be run after 5am every day,
the number of minutes after 5am that it will be run at are set in `~/.cron_min`.

## Hourly

If the `~/bin/cron_hourly.sh` file exists then it will be run every hour, the
number of minutes after each hour that it will be run at are set in `~/.cron_min`.

## Minutely

If the `~/bin/cron_minutely.sh` file exists then it will be run every minute.
