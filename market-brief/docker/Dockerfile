FROM python:3.12-alpine

# bash, curl, jq, gawk for the script; tzdata + dcron for scheduled runs
RUN apk add --no-cache bash curl jq gawk tzdata dcron \
    && cp /usr/share/zoneinfo/America/New_York /etc/localtime \
    && echo "America/New_York" > /etc/timezone

WORKDIR /app
COPY push-market-brief.sh /app/push-market-brief.sh
RUN chmod +x /app/push-market-brief.sh

COPY crontab /etc/crontabs/root
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

RUN mkdir -p /var/log && touch /var/log/market-brief.log

CMD ["/app/entrypoint.sh"]
