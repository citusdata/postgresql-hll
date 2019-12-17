FROM postgres:10.7 as postgres-builder

RUN apt-get update && apt-get install -y build-essential postgresql postgresql-server-dev-10
COPY . ./
ENV VER=2.12
ENV PGSHRT=11
RUN make
RUN make install
