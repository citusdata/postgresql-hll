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

# For each file name "foo":
#
# foo.sql				- test script
# foo.ref				- expected output
# ../testdata/foo.csv	- (optional data file for \copy from pstdin)
# foo.out				- actual output

SQL =	\
		add_agg.sql \
		auto_sparse.sql \
		explicit_thresh.sql \
		nosparse.sql \
		agg_oob.sql \
		cast_shape.sql \
		scalar_oob.sql \
		typmod.sql \
		typmod_insert.sql \
		hash.sql \
		murmur_bigint.sql \
		murmur_bytea.sql \
		equal.sql \
		notequal.sql \
		union_op.sql\
		card_op.sql \
		meta_func.sql \
		transaction.sql \
		storedproc.sql \
		cumulative_add_cardinality_correction.sql \
		cumulative_add_comprehensive_promotion.sql \
		cumulative_add_sparse_edge.sql \
		cumulative_add_sparse_random.sql \
		cumulative_add_sparse_step.sql \
		cumulative_union_comprehensive.sql \
		cumulative_union_explicit_explicit.sql \
		cumulative_union_explicit_promotion.sql \
		cumulative_union_probabilistic_probabilistic.sql \
		cumulative_union_sparse_full_representation.sql \
		cumulative_union_sparse_promotion.sql \
		cumulative_union_sparse_sparse.sql \
		$(NULL)

TEST_DB = hll_regress

NOT =	\
		$(NULL)

OUT := $(SQL:%.sql=%.out)

# Print NULL values explicitly.
PSQLOPTS = --echo-all -P null=NULL

all:	$(OUT)

clean:
	rm -f $(OUT)

# If a matching testdata file exists use it as standard input.
# Otherwise the test doesn't need data on stdin.
#
%.out:	%.sql %.ref
	@echo $*
	@if test -f ../testdata/$*.csv; then \
	  cat ../testdata/$*.csv | \
	  psql $(PSQLOPTS) $(TEST_DB) -f $*.sql &> $*.out && diff -u $*.ref $*.out; \
	else \
	  psql $(PSQLOPTS) $(TEST_DB) -f $*.sql &> $*.out && diff -u $*.ref $*.out; \
    fi
