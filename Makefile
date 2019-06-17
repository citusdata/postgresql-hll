# Copyright 2013 Aggregate Knowledge, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
EXTENSION = hll
EXTVERSIONS = 2.10 2.11 2.12 2.13 2.14

DATA_built = $(foreach v,$(EXTVERSIONS),$(EXTENSION)--$(v).sql) $(wildcard $(EXTENSION)--*--*.sql)

MODULE_big = $(EXTENSION)
OBJS = $(patsubst %.c,%.o,$(wildcard src/*.c)) $(patsubst %.cpp,%.o,$(wildcard src/*.cpp))

PG_CPPFLAGS = -fPIC -Wall -Wextra -Werror -Wno-unused-parameter -Wno-implicit-fallthrough -Iinclude -I$(libpq_srcdir)

REGRESS = setup $(filter-out setup,$(patsubst sql/%.sql,%,$(sort $(wildcard sql/*.sql))))

PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

SHLIB_LINK	+= -lstdc++
SQLPP ?= cpp -undef -w -P -imacros $(shell $(PG_CONFIG) --includedir-server)/pg_config.h

src/hll.o: override CFLAGS += -std=c99

%.sql: update/%.sql
	$(SQLPP) $^ > $@

$(EXTENSION)--2.11.sql: $(EXTENSION)--2.10.sql $(EXTENSION)--2.10--2.11.sql
	cat $^ > $@
$(EXTENSION)--2.12.sql: $(EXTENSION)--2.11.sql $(EXTENSION)--2.11--2.12.sql
	cat $^ > $@
$(EXTENSION)--2.13.sql: $(EXTENSION)--2.12.sql $(EXTENSION)--2.12--2.13.sql
	cat $^ > $@
$(EXTENSION)--2.14.sql: $(EXTENSION)--2.13.sql $(EXTENSION)--2.13--2.14.sql
	cat $^ > $@
