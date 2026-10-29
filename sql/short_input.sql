-- Serialized HLL values require a three-byte header.
SELECT E'\\x'::hll;
SELECT E'\\x14'::hll;
SELECT E'\\x148b'::hll;
