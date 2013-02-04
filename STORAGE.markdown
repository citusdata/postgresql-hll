Storage Specification
=====================

This document is a specification for the Postgres `hll` storage format.

Algorithms & Types
------------------

A `hll` is a combination of different set/distinct-value-counting algorithms that can be thought of as a hierarchy, along with rules for moving up that hierarchy. In order to distinguish between said algorithms, we have given them names:

### `EMPTY` ###
A constant value that denotes the empty set.

### `EXPLICIT` ###
An explicit, unique, sorted list of integers in the set, which is maintained up to a fixed cardinality.

### `SPARSE` ###
A 'lazy', map-based implementation of HyperLogLog, a probabilistic set data structure. Only stores the indices and values of non-zero registers in a map, until the number of non-zero registers exceeds a fixed cardinality.

### `FULL` ###
A fully-materialized, list-based implementation of HyperLogLog. Explicitly stores the value of every register in a list ordered by register index.

For brevity's sake, we'll refer to these different algorithms as 'types'.

Storage
-------

These data structures are stored as zero-indexed array of bytes with a schema version specified in the top nibble of the zero-th byte. The schema version decides both the specific storage layout as well as the rules for the interaction of the different types mentioned above.

The storage specification can trivially be converted into a serialization format by simply encoding the arrays of bytes. The storage specification includes how to represent the various set-like structures as arrays of bytes, as well as how to represent the results of operations on multiple sets (such as an undefined result).

**NOTE:** all examples and diagrams will use a hex format with the high nibble first (on the left) in the octet, and the zero-th octet on the left.

In a pseudo-regex format, the storage layout of the bytes is as follows: `^VS*$`

* `^` symbolizes the beginning of the array of bytes, right before the zero-indexed byte
* `V` is the 'version' byte, indicating the schema version in the top nibble. The bottom nibble is schema version-dependent.
* `S` is a byte specified by the particular schema version. See below.
* `$` symbolizes the end of the array of bytes, right after the highest-indexed byte

Each schema version will elaborate on the above layout.

Schema Version
--------------

### Schema Version `1` ###

+ **Size/Layout**
    + **Size/Layout**

    * _Minimum length:_ 3 bytes
    * _Maximum length:_ 2,147,483,651 bytes ( = (2<sup>31</sup> * 8) + 3)

    * The schema-specific bytes `S*` have the following structure: `PCB*`
        
        * `P` is the _required_ 'parameter' byte. See 'Type-agnostic' subsection.
        * `C` is the _required_ 'cutoff' byte. See 'Type-agnostic' subsection.
        * `B` is a 'data' byte. The 'data' bytes layout is specified per type. See 'Type-specific' subsection.

+ **Type-agnostic**

    * The bottom nibble of the 'version' byte `V` indicates the type, as defined by these ordinals:

        * `0` - undefined
        * `1` - `EMPTY`
        * `2` - `EXPLICIT`
        * `3` - `SPARSE`
        * `4` - `FULL`

    * The 'parameter' byte `P` encodes the bit-width and number of registers used by `SPARSE` and `FULL` types.

        * the highest 3 bits are used to encode the integer value `registerWidth - 1`, and
        * the remaining 5 bits encode the integer value `log2(numberOfRegisters)`.
    
    `registerWidth` may take values from 1 to 8, inclusive, and `log2(numberOfRegisters)` may take on 1 to 31, inclusive.

    For example:

            P = xA6 = 1010 0110 = 101 00110
    thus
            registerWidth - 1 = 5
            registerWidth = 6
    and
            log2(numberOfRegisters) = 6
            numberOfRegisters = 2^6 = 64

    * The 'cutoff' byte `C` encodes parameters defining the `EXPLICIT` to `SPARSE`, and `SPARSE` to `FULL` promotions.
        
        * 1 bit (the top bit) of padding,
        * 1 bit (second highest bit) indicating the boolean value `sparseEnabled`, and
        * 6 bits (lowest six bits) as a big-endian integer `explicitCutoff` that can take on the values `0`, `63`, or `1` to `31` inclusive.

+ **Type-specific**
    * undefined/invalid result
    
        Uses no data bytes.

    * `EMPTY`

        Uses no data bytes.

    * `EXPLICIT`

	   The layout of the 'data' bytes is: `(B{8}){0,256}`, that is 0-256 blocks of 8 bytes. Each block of 8 bytes represent a signed 64-bit integer (sign bit + 63 value bits). These integers are encoded as big-endian (with sign-bit at highest position), and are the "contents" of the set. (The blocks together represent an array of such integers, stored in ascending order, without duplicates.)

            data bytes
            = [-5451491901947305642, 1]                   # as ascending, signed, decimal-encoded 64-bit values in array
        	= [0xCBA79700677CDEAA, 0x0000000000000001]    # as hex-encoded 64-bit values in array
            = 0xCBA79700677CDEAA0000000000000001          # as hex

    * `SPARSE`

        The data bytes encode the register indices and values in `(log2(numberOfRegisters) + registerWidth)`-bit-wide "short-words". Each short-word is a bit-packed register `index`/register `value` pair.

            * The `index` is encoded in the highest `log2(numberOfRegisters)` bits of the short-word.
            * The `value` is encoded in the lowest `registerWidth` bits of the short-word.

        The short-words are packed into bytes from the top of the zero-th data byte to the bottom of the last data byte, with the high bits of a short-word toward the high bits of a byte.

            * If `BITS = (registerWidth + log2(numberOfRegisters)) * numberOfRegisters` is not divisible by 8, then `BITS % 8` padding bits are added to the _bottom_ of the _last_ byte of the array.
            * The short-words are stored in ascending `index` order.

        For example, if `log2(numberOfRegisters) = 11` and `registerWidth = 6`, and if the  register index/value pairs are `(11, 6)` and `(1099, 19)`:

            = [(11, 6), (1099, 19), padding]                                    # as unsigned decimal-encoded pairs
            = [(0b00000001011, 0b000110), (0b10001001011, 0b010011), 0b000000]  # as two binary-encoded pairs and 6 bits of padding
            = [(0b00000001011000110), (0b10001001011010011), 0b000000]          # as binary-encoded 17-bit short words and 6 bits of padding
            = [0b00000001, 0b01100011, 0b01000100, 0b10110100, 0b11000000]      # as binary-encoded octets in array
            = [0x01, 0x63, 0x44, 0x5B, 0xC0]                                    # as byte array
              0x0163445BC0                                                      # as hex

        This encoding was chosen so that when reading bytes as octets in the typical first-octet-is-the-high-4-bits fashion, a octet-to-binary conversion as demonstrated above would yield a high-to-low, left-to-right view of the "short words" and their components.

    * `FULL`

        The data bytes encode the register values in `registerWidth`-bit-wide, big-endian "short-words". The short words are written from the top of the zero-th byte of the array to the bottom of the last byte of the array, with the high bits of a short-word toward the high bits of a byte.

            * If `BITS = registerWidth * numberOfRegisters` is not divisible by 8, then `BITS % 8` padding bits are added to the _bottom_ of the _last_ byte of the array.
            * The short-words are stored in ascending index order.

        For example, if `registerWidth = 5` and `numberOfRegisters = 4`, and if the register index/value pairs are `(0, 0), (1,1), (2,2), (3,3)`:

              [0, 1, 2, 3, padding]                        # as unsigned decimal-encoded register values
            = [0b00000, 0b00001, 0b00010, 0b00011, 0b0000] # as four 5-bit "short words" + 4 bits padding
            = [0b00000000, 0b01000100, 0b00110000]         # as binary-encoded octets in array
            = [0x00, 0x44, 0x30]                           # as hex-encoded byte array
            = 0x004430                                     # as hex

+ **Hierarchy**

    * The hierarchy is dependent on the 'cutoff' byte `C`. When a set is promoted from one 'type'/algorithm to another, the top nibble of the 'version' byte `V`, the 'parameter' byte `P`, and the 'cutoff' byte `C` all remain the same. The bottom nibble of `V` and the 'data' bytes `B` may change.
    * When any value is added to an `EMPTY` set,

        * if `explicitCutoff = 0` and `sparseEnabled = 0`, then it is promoted to a `FULL` set containing that one value.
        * if `explicitCutoff = 0` and `sparseEnabled = 1`, then it is promoted to a `SPARSE` set containing that one value.
        * if `explicitCutoff > 0` but `< 63`, then it is promoted to an `EXPLICIT` set containing that one value.

    * When inserting an element into an `EXPLICIT` set,

        * if `sparseEnabled = 0` and `explicitCutoff = 0`, then it is promoted to a `FULL` set.
        * if `sparseEnabled = 1` and `explicitCutoff = 0`, then it is promoted to a `SPARSE` set.
        * if `sparseEnabled = 0` and `explicitCutoff > 0` and `< 63`, and if inserting the element would cause the cardinality to exceed `2 ^ (explicitCutoff - 1)`, then it is promoted to a `FULL`.
        * if `sparseEnabled = 1` and `explicitCutoff > 0` and `< 63`, and if inserting the element would cause the cardinality to exceed `2 ^ (explicitCutoff - 1)`, then it is promoted to a `SPARSE`.
        * if `sparseEnabled = 0` and `explicitCutoff = 63`, then the criteria for promotion is implementation-dependent, as this value of `explicitCutoff` indicates an 'auto' promotion mode. Since `sparseEnabled = 0` the set can only be promoted to a `FULL` set.
        * if `sparseEnabled = 1` and `explicitCutoff = 63`, then the promotion is implementation-dependent, as this value of `explicitCutoff` indicates an 'auto' promotion mode. Since `sparseEnabled = 1` the set can only be promoted to a `SPARSE` set.

    * When inserting an element into a `SPARSE` set, if that element would cause the storage size of the `SPARSE` set to be greater than that of a `FULL` set, then it is promoted to a `FULL` set.