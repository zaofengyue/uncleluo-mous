FROM uncleluo/mous:latest
RUN apt-get update -qq && apt-get install -y -qq nginx && rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh /entrypoint.sh
COPY index.html /index.html
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
