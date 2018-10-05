#! /usr/bin/env bash

if [ -z "$SIGNON_URL" ]; then
  >&2 echo "SIGNON_URL environment variable not set"
  exit
fi

if [ -z "$SIGNON_EMAIL" ]; then
  >&2 echo "SIGNON_EMAIL environment variable not set"
  exit
fi

if [ -z "$SIGNON_PASSWORD" ]; then
  >&2 echo "SIGNON_PASSWORD environment variable not set"
  exit
fi

SIGNON_SIGNIN_URL="$SIGNON_URL/users/sign_in"
COOKIE_JAR=$(mktemp)
TOKENS=$(mktemp)

function loginToSignon() {
  local BODY=$(curl --silent --cookie-jar $COOKIE_JAR $SIGNON_SIGNIN_URL)
  local CSRF_TOKEN=$(echo $BODY | gawk '{ match($0, /<meta name=\"csrf-token\" content=\"([^ ]+)\" \/>/, arr); print arr[1]; }')

  if [ $? != 0 ] || [ -z "$CSRF_TOKEN" ]; then
    >&2 echo "Error getting CSRF token for Signon"
    >&2 echo $BODY
    exit
  fi

  local BODY=$(curl --silent --cookie $COOKIE_JAR --cookie-jar $COOKIE_JAR -F "authenticity_token=$CSRF_TOKEN" -F "user[email]=$SIGNON_EMAIL" -F "user[password]=$SIGNON_PASSWORD" $SIGNON_SIGNIN_URL)

  if [ $? != 0 ] || [ -z "$BODY" ]; then
    >&2 echo "Error signing in to Signon"
    >&2 echo $BODY
    exit
  fi
}

function tokenForApp {
  if grep -q "$1" $TOKENS; then
    return
  fi

  local BODY=$(curl -L --silent --cookie $COOKIE_JAR --cookie-jar $COOKIE_JAR $1)
  local CSRF_TOKEN=$(echo $BODY | gawk '{ match($0, /<meta name=\"csrf-token\" content=\"([^ ]+)\" \/>/, arr); print arr[1]; }')

  if [ $? != 0 ] || [ -z "$CSRF_TOKEN" ]; then
    >&2 echo "Error getting CSRF token for $1"
    >&2 echo $BODY
    exit
  fi

  echo "$1 $CSRF_TOKEN" >> $TOKENS
}

loginToSignon

while read line; do
  DECODED=$(echo "$line" | xxd -r -p)

  HOST=$(echo "$DECODED" | grep 'Host:' | sed "s/Host: \(.*\)$(printf '\r')/\1/")
  if [ -z "$HOST" ]; then continue; fi
  tokenForApp "https://$HOST"

  COOKIES=$(cat $COOKIE_JAR | tail -n +5 | awk '{ printf "%s=%s\n", $6, $7 }' | paste -sd ';' - | sed -e 's/[\/&]/\\&/g')
  DECODED=$(sed "s/Cookie: .*$(printf '\r')/Cookie: $COOKIES$(printf '\r')/" <<< "$DECODED")

  TOKEN=$(grep "https://$HOST" $TOKENS | cut -d' ' -f 2)
  TOKEN=$(python -c "import urllib, sys; print urllib.quote(sys.argv[1])" "$TOKEN" | sed -e 's/[\/&]/\\&/g')
  DECODED=$(sed "s/authenticity_token=[^\&]*\&/authenticity_token=$TOKEN\&/" <<< "$DECODED")

  LENGTH=$(echo -e "$DECODED" | tail -n 1 | wc -c)
  DECODED=$(sed "s/Content-Length: .*$(printf '\r')/Content-Length: $LENGTH$(printf '\r')/" <<< "$DECODED")

  echo $(echo "$DECODED" | xxd -p | tr -d "\\n")
done

rm $COOKIE_JAR
rm $TOKENS
