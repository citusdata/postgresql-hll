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
EXTVERSION = 2.10

DATA_built = $(EXTENSION)--$(EXTVERSION).sql
DATA = $(wildcard $(EXTENSION)--*--*.sql)

MODULE_big = $(EXTENSION)
OBJS = src/hll.o \
       src/MurmurHash3.o

PG_CPPFLAGS = -fPIC -Wall -Wextra -Werror -Wno-unused-parameter -Wno-implicit-fallthrough -Iinclude -I$(libpq_srcdir)

REGRESS = setup $(filter-out setup,$(patsubst sql/%.sql,%,$(sort $(wildcard sql/*.sql))))

PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

src/hll.o: override CFLAGS += -std=c99

$(EXTENSION)--2.10.sql: $(EXTENSION).sql
	cat $^ > $@

