# goreplay-govuk-middleware

Experimental middleware to replay publishing traffic on GOV.UK

## Background

[Goreplay](https://github.com/buger/goreplay) ('gor') is a tool used by GOV.UK to record and replay traffic for our frontend apps in our staging environment, which helps ensure the environment is realistic for testing.

Frontend traffic is primarily GET requests, which can easily be replayed. For backend traffic, the more interesting requests are POST, PUT, PATCH and DELETE, which usually require authentication, which is hard to replay.

This project is a piece of gor middleware that modifies the recorded traffic so that it authenticates successfully, using a test account for GOV.UK Signon that has the required access to each app we want to replay traffic for.

## Record / Replay

First download [gor](https://github.com/buger/goreplay/releases) onto the recording and the replay machine(s).

```
wget https://github.com/buger/goreplay/releases/download/v0.16.1/gor_0.16.1_x64.tar.gz
tar -zxvf gor_0.16.1_x64.tar.gz
```

Now record some traffic to a file for one or more apps (check the ports in [govuk-puppet](https://github.com/alphagov/govuk-puppet/blob/master/development-vm/Procfile)).

```
# after the AWS migration, it will be easy to grab everything using just :80
sudo ./goreplay -input-raw :3221 -input-raw :3116 -output-file my_recording
```

After copying the file (and `middleware.sh`) to the replay machine, run the following to replay the traffic.

```
export SIGNON_URL=<signon_url_for_this_environment>
export SIGNON_EMAIL=<signon_email_for_smokey>
export SIGNON_PASSWORD=<signon_password_for_smokey>

./goreplay --input-file pubreplay_0 -middleware './middleware.sh' --http-rewrite-header 'Host: (.*).staging.publishing.service.gov.uk,$1.integration.publishing.service.gov.uk' -http-original-host -output-http http://localhost -output-stdout
```

You may need to grant the `Smokey (test user)` (additional) access for the replay to work on certain apps.

## Thing To Do

* Test with some more realistic traffic (e.g. Whitehall)
* Currently only supports RUD - make it work for **C**RUD
* Track parity of responses between record/replay traffic
* Think about a sensible way of deploying this to GOV.UK
