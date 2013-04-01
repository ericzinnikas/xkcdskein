module SkeinR
  def SkeinR::word32_to_bytes(n, b, ofs)
    b[ofs    ] =  n        & 0x0ff
    b[ofs + 1] = (n >>  8) & 0x0ff
    b[ofs + 2] = (n >> 16) & 0x0ff
    b[ofs + 3] = (n >> 24) & 0x0ff
    return ofs + 4
  end

  def SkeinR::word64_to_bytes(n, b, ofs)
    b[ofs    ] =  n        & 0x0ff
    b[ofs + 1] = (n >>  8) & 0x0ff
    b[ofs + 2] = (n >> 16) & 0x0ff
    b[ofs + 3] = (n >> 24) & 0x0ff
    b[ofs + 4] = (n >> 32) & 0x0ff
    b[ofs + 5] = (n >> 40) & 0x0ff
    b[ofs + 6] = (n >> 48) & 0x0ff
    b[ofs + 7] = (n >> 56) & 0x0ff
    return ofs + 8
  end

  def SkeinR::words64_to_n_bytes(w, wofs, b, bofs, n)
    for i in 0..n-1
      b[bofs + i] = (w[wofs + (i >> 3)] >> ((i & 7) << 3)) & 0x0ff
    end
    return bofs + n
  end

  def SkeinR::bytes_to_word64(b, bofs)
    return  (b[bofs    ] & 0x0ff)        |
           ((b[bofs + 1] & 0x0ff) <<  8) |
           ((b[bofs + 2] & 0x0ff) << 16) |
           ((b[bofs + 3] & 0x0ff) << 24) |
           ((b[bofs + 4] & 0x0ff) << 32) |
           ((b[bofs + 5] & 0x0ff) << 40) |
           ((b[bofs + 6] & 0x0ff) << 48) |
           ((b[bofs + 7] & 0x0ff) << 56);
  end

  def SkeinR::add64(x, y)
    (x + y) & 0xffff_ffff_ffff_ffff
  end

  def SkeinR::rotl64(x, n)
    n &= 63
    ((x << n) | (x >> (64 - n))) & 0xffff_ffff_ffff_ffff
  end

  def SkeinR::bytes_to_words64(b, bofs, w, wofs, wn)
    for i in 1..wn
      w[wofs] = bytes_to_word64(b, bofs)
      wofs += 1
      bofs += 8
    end
    return wofs
  end

  def SkeinR::hex_to_bytes(h)
    len = h.length
    return nil if len & 1 == 1
    result = Array.new((len &= ~1)/2)
    for i in 0..result.length - 1
      result[i] = h[i*2..(i*2)+1].hex
    end
    return result
  end

  def SkeinR::bytes_to_hex(b, ofs = 0, len = b.length, cols = 0, sepa = '')
    hextab = %w{ 0 1 2 3 4 5 6 7 8 9 A B C D E F }
    return words_to_hex(b, ofs, len, cols, sepa) { |wi|
      result = ""
      result << hextab[(wi >> 4) & 15]
      result << hextab[ wi       & 15]
    }
  end

  def SkeinR::words64_to_hex(w, ofs, len, cols = 0, sepa = ' ', split = ':')
    return words_to_hex(w, ofs, len, cols, sepa) { |wi|
      sprintf("%08X%s%08X", wi >> 32, split, wi & 0x0ffff_ffff)
    }
  end

  def SkeinR::words_to_hex(w, ofs, len, cols = 0, sepa = ' ')
    result = ""
    s = ""
    for i in 0..len - 1
      wi = w[ofs + i]
      lf = 0 < cols && 0 == (i + 1) % cols && len - 1 > i
      result <<= sprintf("%s%s", s, yield(wi))
      if lf
        s = ""
      else
        s = sepa
      end
      result <<= "\n" if lf
    end
    return result
  end

  ############################################################################

  DEBUG = false

  def SkeinR::dbgf(fmt, *args)
    if DEBUG
      printf(fmt + "\n", *args)
    end
  end

  ############################################################################

  MODIFIER_WORDS = 2
  ID_STRING_LE   = 0x33414853
  VERSION        = 1
  KS_PARITY      = 0x1BD11BDA_A9FC1A22
  BIT_FIRST      = (1 << (126 - 64))
  BIT_FINAL      = (1 << (127 - 64))
  CFG_STR_LEN    = 32

  ############################################################################

  class Hash
    attr_accessor :hashbitlen
    attr_accessor :cnt
    attr_accessor :X
    attr_accessor :b
    attr_accessor :T
    def initialize(hashbitlen, x, b)
      @hashbitlen = hashbitlen
      @X = Array.new(x, 0)
      @b = Array.new(b, 0)
      @T = Array.new(MODIFIER_WORDS, 0)
      @cnt = 0
    end
    def inject_key(r, wcnt, x, ks, ts)
      for i in 0..wcnt-1
        x[i] = SkeinR::add64(x[i], ks[(r + i) % (wcnt + 1)])
      end
      x[wcnt - 3] = SkeinR::add64(x[wcnt - 3], ts[(r + 0) % 3])
      x[wcnt - 2] = SkeinR::add64(x[wcnt - 2], ts[(r + 1) % 3])
      x[wcnt - 1] = SkeinR::add64(x[wcnt - 1], r)
    end
    def update_str(obj)
      obj.to_s.each_byte do |byte|
        update(byte)
      end
      self
    end
  end

  ############################################################################

  class Hash256 < Hash
    BLOCK_BYTES  = 32
    STATE_WORDS  = 4
    ROUNDS_TOTAL = 72
    def initialize(hashbitlen = 256)
      super(hashbitlen, STATE_WORDS, BLOCK_BYTES)
      cfg = Array.new(@b.length, 0)
      SkeinR::word32_to_bytes(ID_STRING_LE, cfg,  0)
      SkeinR::word32_to_bytes(VERSION     , cfg,  4)
      SkeinR::word64_to_bytes(hashbitlen  , cfg,  8)
      SkeinR::word64_to_bytes(0           , cfg, 16)
      @T[1] = BIT_FIRST | (4 << (120 - 64)) | BIT_FINAL
      @local_ts = Array.new(3, 0)
      @local_ks = Array.new(STATE_WORDS + 1, 0)
      @local_X  = Array.new(STATE_WORDS, 0)
      @local_w  = Array.new(STATE_WORDS, 0)
      process_block(cfg, 0, CFG_STR_LEN)
      @T[0] = @cnt = 0
      @T[1] = BIT_FIRST | (48 << (120 - 64))
    end
    def update(byte)
      if (@cnt == @b.length)
        process_block(@b, 0, @b.length)
        @cnt = 0
      end
      @b[@cnt] = byte
      @cnt += 1
      self
    end
    def final
      @T[1] |= BIT_FINAL
      for i in @cnt..@b.length-1
        @b[i] = 0
      end
      process_block(@b, 0, @cnt)
      byteCnt = (@hashbitlen + 7) >> 3;
      result = Array.new(byteCnt, 0)
      x = @X.dup
      @b.fill(0)
      i = 0
      while (i * BLOCK_BYTES) < byteCnt
        SkeinR::word64_to_bytes(i, @b, 0)
        @T[0] = 0
        @T[1] = BIT_FIRST | (63 << (120 - 64)) | BIT_FINAL
        @cnt = 0
        process_block(@b, 0, 8)
        n = byteCnt - i* BLOCK_BYTES;
        n = BLOCK_BYTES if n >= BLOCK_BYTES
        SkeinR::words64_to_n_bytes(@X, 0, result, i * BLOCK_BYTES, n)
        @X = x.dup
        i += 1
      end
      return result
    end
    R_256_0_0 = 14; R_256_0_1 = 16
    R_256_1_0 = 52; R_256_1_1 = 57
    R_256_2_0 = 23; R_256_2_1 = 40
    R_256_3_0 =  5; R_256_3_1 = 37
    R_256_4_0 = 25; R_256_4_1 = 33
    R_256_5_0 = 46; R_256_5_1 = 12
    R_256_6_0 = 58; R_256_6_1 = 22
    R_256_7_0 = 32; R_256_7_1 = 32
    def process_block(blk, ofs, byteCntAdd)
      wcnt = STATE_WORDS
      ts = @local_ts
      ks = @local_ks
      x  = @local_X
      w  = @local_w
      @T[0] += byteCntAdd
      ks[wcnt] = KS_PARITY
      for i in 0..wcnt-1
        ks[i]     = @X[i]
        ks[wcnt] ^= @X[i]
      end
      ts[0] = @T[0]
      ts[1] = @T[1]
      ts[2] = ts[0] ^ ts[1]
      #SkeinR::dbgf("ts: %s", SkeinR::words64_to_hex(ts, 0, ts.length, ts.length))
      #SkeinR::dbgf("input block:\n%s", SkeinR::bytes_to_hex(blk, ofs, wcnt*8, 16, ' '))
      SkeinR::bytes_to_words64(blk, ofs, w, 0, wcnt)
      for i in 0..wcnt-1
        x[i] = SkeinR::add64(w[i], ks[i])
      end
      x[wcnt - 3] = SkeinR::add64(x[wcnt - 3], ts[0])
      x[wcnt - 2] = SkeinR::add64(x[wcnt - 2], ts[1])
      #SkeinR::dbgf("after initkinj: %s", SkeinR::words64_to_hex(x, 0, x.length, x.length))
      for r in 1..ROUNDS_TOTAL/8
        x[0] = SkeinR::add64(x[0], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_0_0); x[1] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_0_1); x[3] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-7, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_1_0); x[3] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_1_1); x[1] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-6, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_2_0); x[1] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_2_1); x[3] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-5, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_3_0); x[3] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_3_1); x[1] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-4, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        inject_key(2 * r - 1, wcnt, x, ks, ts)                                                ; #SkeinR::dbgf("after keyinj#1: %s" ,        SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_4_0); x[1] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_4_1); x[3] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-3, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_5_0); x[3] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_5_1); x[1] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-2, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_6_0); x[1] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_6_1); x[3] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-1, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[3]); x[3] = SkeinR::rotl64(x[3], R_256_7_0); x[3] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[1]); x[1] = SkeinR::rotl64(x[1], R_256_7_1); x[1] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8  , SkeinR::words64_to_hex(x, 0, x.length, x.length))
        inject_key(2 * r, wcnt, x, ks, ts)                                                    ; #SkeinR::dbgf("after keyinj#2: %s" ,        SkeinR::words64_to_hex(x, 0, x.length, x.length))
      end
      for i in 0..wcnt-1
        @X[i] = x[i] ^ w[i]
      end                                                                                     ; #SkeinR::dbgf("after ptxtfdfw: %s", SkeinR::words64_to_hex(@X, 0, @X.length, @X.length))
      @T[1] &= ~BIT_FIRST
    end
  end

  #############################################################################

  class Hash512 < Hash
    BLOCK_BYTES  = 64
    STATE_WORDS  = 8
    ROUNDS_TOTAL = 72
    def initialize(hashbitlen = 512)
      super(hashbitlen, STATE_WORDS, BLOCK_BYTES)
      cfg = Array.new(@b.length, 0)
      SkeinR::word32_to_bytes(ID_STRING_LE, cfg,  0)
      SkeinR::word32_to_bytes(VERSION     , cfg,  4)
      SkeinR::word64_to_bytes(hashbitlen  , cfg,  8)
      SkeinR::word64_to_bytes(0           , cfg, 16)
      @T[1] = BIT_FIRST | (4 << (120 - 64)) | BIT_FINAL
      @local_ts = Array.new(3, 0)
      @local_ks = Array.new(STATE_WORDS + 1, 0)
      @local_X  = Array.new(STATE_WORDS, 0)
      @local_w  = Array.new(STATE_WORDS, 0)
      process_block(cfg, 0, CFG_STR_LEN)
      @T[0] = @cnt = 0
      @T[1] = BIT_FIRST | (48 << (120 - 64))
    end
    def update(byte)
      if (@cnt == @b.length)
        process_block(@b, 0, @b.length)
        @cnt = 0
      end
      @b[@cnt] = byte
      @cnt += 1
      self
    end
    def final
      @T[1] |= BIT_FINAL
      for i in @cnt..@b.length-1
        @b[i] = 0
      end
      process_block(@b, 0, @cnt)
      byteCnt = (@hashbitlen + 7) >> 3;
      result = Array.new(byteCnt, 0)
      x = @X.dup
      @b.fill(0)
      i = 0
      while (i * BLOCK_BYTES) < byteCnt
        SkeinR::word64_to_bytes(i, @b, 0)
        @T[0] = 0
        @T[1] = BIT_FIRST | (63 << (120 - 64)) | BIT_FINAL
        @cnt = 0
        process_block(@b, 0, 8)
        n = byteCnt - i* BLOCK_BYTES;
        n = BLOCK_BYTES if n >= BLOCK_BYTES
        SkeinR::words64_to_n_bytes(@X, 0, result, i * BLOCK_BYTES, n)
        @X = x.dup
        i += 1
      end
      return result
    end
    R_512_0_0 = 46; R_512_0_1 = 36; R_512_0_2 = 19; R_512_0_3 = 37
    R_512_1_0 = 33; R_512_1_1 = 27; R_512_1_2 = 14; R_512_1_3 = 42
    R_512_2_0 = 17; R_512_2_1 = 49; R_512_2_2 = 36; R_512_2_3 = 39
    R_512_3_0 = 44; R_512_3_1 =  9; R_512_3_2 = 54; R_512_3_3 = 56
    R_512_4_0 = 39; R_512_4_1 = 30; R_512_4_2 = 34; R_512_4_3 = 24
    R_512_5_0 = 13; R_512_5_1 = 50; R_512_5_2 = 10; R_512_5_3 = 17
    R_512_6_0 = 25; R_512_6_1 = 29; R_512_6_2 = 39; R_512_6_3 = 43
    R_512_7_0 =  8; R_512_7_1 = 35; R_512_7_2 = 56; R_512_7_3 = 22
    def process_block(blk, ofs, byteCntAdd)
      wcnt = STATE_WORDS
      ts = @local_ts
      ks = @local_ks
      x  = @local_X
      w  = @local_w
      @T[0] += byteCntAdd
      ks[wcnt] = KS_PARITY
      for i in 0..wcnt-1
        ks[i]     = @X[i]
        ks[wcnt] ^= @X[i]
      end
      ts[0] = @T[0]
      ts[1] = @T[1]
      ts[2] = ts[0] ^ ts[1]
      #SkeinR::dbgf("ts: %s", SkeinR::words64_to_hex(ts, 0, ts.length, ts.length))
      #SkeinR::dbgf("input block:\n%s", SkeinR::bytes_to_hex(blk, ofs, wcnt*8, 16, ' '))
      SkeinR::bytes_to_words64(blk, ofs, w, 0, wcnt)
      for i in 0..wcnt-1
        x[i] = SkeinR::add64(w[i], ks[i])
      end
      x[wcnt - 3] = SkeinR::add64(x[wcnt - 3], ts[0])
      x[wcnt - 2] = SkeinR::add64(x[wcnt - 2], ts[1])
      SkeinR::dbgf("after initkinj: %s", SkeinR::words64_to_hex(x, 0, x.length, x.length))
      for r in 1..ROUNDS_TOTAL/8
        x[0] = SkeinR::add64(x[0], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_0_0); x[1] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_0_1); x[3] ^= x[2]
        x[4] = SkeinR::add64(x[4], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_0_2); x[5] ^= x[4]
        x[6] = SkeinR::add64(x[6], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_0_3); x[7] ^= x[6]; #SkeinR::dbgf("after round %2d: %s", r*8-7, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[2] = SkeinR::add64(x[2], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_1_0); x[1] ^= x[2]
        x[4] = SkeinR::add64(x[4], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_1_1); x[7] ^= x[4]
        x[6] = SkeinR::add64(x[6], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_1_2); x[5] ^= x[6]
        x[0] = SkeinR::add64(x[0], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_1_3); x[3] ^= x[0]; #SkeinR::dbgf("after round %2d: %s", r*8-6, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[4] = SkeinR::add64(x[4], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_2_0); x[1] ^= x[4]
        x[6] = SkeinR::add64(x[6], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_2_1); x[3] ^= x[6]
        x[0] = SkeinR::add64(x[0], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_2_2); x[5] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_2_3); x[7] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-5, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[6] = SkeinR::add64(x[6], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_3_0); x[1] ^= x[6]
        x[0] = SkeinR::add64(x[0], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_3_1); x[7] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_3_2); x[5] ^= x[2]
        x[4] = SkeinR::add64(x[4], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_3_3); x[3] ^= x[4]; #SkeinR::dbgf("after round %2d: %s", r*8-4, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        inject_key(2 * r - 1, wcnt, x, ks, ts)                                                ; #SkeinR::dbgf("after keyinj#1: %s" ,        SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[0] = SkeinR::add64(x[0], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_4_0); x[1] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_4_1); x[3] ^= x[2]
        x[4] = SkeinR::add64(x[4], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_4_2); x[5] ^= x[4]
        x[6] = SkeinR::add64(x[6], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_4_3); x[7] ^= x[6]; #SkeinR::dbgf("after round %2d: %s", r*8-3, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[2] = SkeinR::add64(x[2], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_5_0); x[1] ^= x[2]
        x[4] = SkeinR::add64(x[4], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_5_1); x[7] ^= x[4]
        x[6] = SkeinR::add64(x[6], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_5_2); x[5] ^= x[6]
        x[0] = SkeinR::add64(x[0], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_5_3); x[3] ^= x[0]; #SkeinR::dbgf("after round %2d: %s", r*8-2, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[4] = SkeinR::add64(x[4], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_6_0); x[1] ^= x[4]
        x[6] = SkeinR::add64(x[6], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_6_1); x[3] ^= x[6]
        x[0] = SkeinR::add64(x[0], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_6_2); x[5] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_6_3); x[7] ^= x[2]; #SkeinR::dbgf("after round %2d: %s", r*8-1, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        x[6] = SkeinR::add64(x[6], x[1]); x[1] = SkeinR::rotl64(x[1], R_512_7_0); x[1] ^= x[6]
        x[0] = SkeinR::add64(x[0], x[7]); x[7] = SkeinR::rotl64(x[7], R_512_7_1); x[7] ^= x[0]
        x[2] = SkeinR::add64(x[2], x[5]); x[5] = SkeinR::rotl64(x[5], R_512_7_2); x[5] ^= x[2]
        x[4] = SkeinR::add64(x[4], x[3]); x[3] = SkeinR::rotl64(x[3], R_512_7_3); x[3] ^= x[4]; #SkeinR::dbgf("after round %2d: %s", r*8  , SkeinR::words64_to_hex(x, 0, x.length, x.length))
        inject_key(2 * r, wcnt, x, ks, ts)                                                    ; #SkeinR::dbgf("after keyinj#2: %s" ,        SkeinR::words64_to_hex(x, 0, x.length, x.length))
      end
      for i in 0..wcnt-1
        @X[i] = x[i] ^ w[i]
      end                                                                                     ; #SkeinR::dbgf("after ptxtfdfw: %s", SkeinR::words64_to_hex(@X, 0, @X.length, @X.length))
      @T[1] &= ~BIT_FIRST
    end
  end

##############################################################################

  class Hash1024 < Hash
    BLOCK_BYTES  = 128
    STATE_WORDS  = 16
    ROUNDS_TOTAL = 80
    def initialize(hashbitlen = 1024)
      super(hashbitlen, STATE_WORDS, BLOCK_BYTES)
      cfg = Array.new(@b.length, 0)
      SkeinR::word32_to_bytes(ID_STRING_LE, cfg,  0)
      SkeinR::word32_to_bytes(VERSION     , cfg,  4)
      SkeinR::word64_to_bytes(hashbitlen  , cfg,  8)
      SkeinR::word64_to_bytes(0           , cfg, 16)
      @T[1] = BIT_FIRST | (4 << (120 - 64)) | BIT_FINAL
      @local_ts = Array.new(3, 0)
      @local_ks = Array.new(STATE_WORDS + 1, 0)
      @local_X  = Array.new(STATE_WORDS, 0)
      @local_w  = Array.new(STATE_WORDS, 0)
      process_block(cfg, 0, CFG_STR_LEN)
      @T[0] = @cnt = 0
      @T[1] = BIT_FIRST | (48 << (120 - 64))
    end
    def update(byte)
      if (@cnt == @b.length)
        process_block(@b, 0, @b.length)
        @cnt = 0
      end
      @b[@cnt] = byte
      @cnt += 1
    end
    def final
      @T[1] |= BIT_FINAL
      for i in @cnt..@b.length-1
        @b[i] = 0
      end
      process_block(@b, 0, @cnt)
      byteCnt = (@hashbitlen + 7) >> 3;
      result = Array.new(byteCnt, 0)
      x = @X.dup
      @b.fill(0)
      i = 0
      while (i * BLOCK_BYTES) < byteCnt
        SkeinR::word64_to_bytes(i, @b, 0)
        @T[0] = 0
        @T[1] = BIT_FIRST | (63 << (120 - 64)) | BIT_FINAL
        @cnt = 0
        process_block(@b, 0, 8)
        n = byteCnt - i* BLOCK_BYTES;
        n = BLOCK_BYTES if n >= BLOCK_BYTES
        SkeinR::words64_to_n_bytes(@X, 0, result, i * BLOCK_BYTES, n)
        @X = x.dup
        i += 1
      end
      return result
    end
    R1024_0_0 = 24; R1024_0_1 = 13; R1024_0_2 =  8; R1024_0_3 = 47; R1024_0_4 =  8; R1024_0_5 = 17; R1024_0_6 = 22; R1024_0_7 = 37
    R1024_1_0 = 38; R1024_1_1 = 19; R1024_1_2 = 10; R1024_1_3 = 55; R1024_1_4 = 49; R1024_1_5 = 18; R1024_1_6 = 23; R1024_1_7 = 52
    R1024_2_0 = 33; R1024_2_1 =  4; R1024_2_2 = 51; R1024_2_3 = 13; R1024_2_4 = 34; R1024_2_5 = 41; R1024_2_6 = 59; R1024_2_7 = 17
    R1024_3_0 =  5; R1024_3_1 = 20; R1024_3_2 = 48; R1024_3_3 = 41; R1024_3_4 = 47; R1024_3_5 = 28; R1024_3_6 = 16; R1024_3_7 = 25
    R1024_4_0 = 41; R1024_4_1 =  9; R1024_4_2 = 37; R1024_4_3 = 31; R1024_4_4 = 12; R1024_4_5 = 47; R1024_4_6 = 44; R1024_4_7 = 30
    R1024_5_0 = 16; R1024_5_1 = 34; R1024_5_2 = 56; R1024_5_3 = 51; R1024_5_4 =  4; R1024_5_5 = 53; R1024_5_6 = 42; R1024_5_7 = 41
    R1024_6_0 = 31; R1024_6_1 = 44; R1024_6_2 = 47; R1024_6_3 = 46; R1024_6_4 = 19; R1024_6_5 = 42; R1024_6_6 = 44; R1024_6_7 = 25
    R1024_7_0 =  9; R1024_7_1 = 48; R1024_7_2 = 35; R1024_7_3 = 52; R1024_7_4 = 23; R1024_7_5 = 31; R1024_7_6 = 37; R1024_7_7 = 20
    def process_block(blk, ofs, byteCntAdd)
      wcnt = STATE_WORDS
      ts = @local_ts
      ks = @local_ks
      x  = @local_X
      w  = @local_w
      @T[0] += byteCntAdd
      ks[wcnt] = KS_PARITY
      for i in 0..wcnt-1
        ks[i]     = @X[i]
        ks[wcnt] ^= @X[i]
      end
      ts[0] = @T[0]
      ts[1] = @T[1]
      ts[2] = ts[0] ^ ts[1]
      #SkeinR::dbgf("ts: %s", SkeinR::words64_to_hex(ts, 0, ts.length, ts.length))
      #SkeinR::dbgf("ks: %s", SkeinR::words64_to_hex(ks, 0, ks.length, ks.length))
      #SkeinR::dbgf("input block:\n%s", SkeinR::bytes_to_hex(blk, ofs, wcnt*8, 16, ' '))
      SkeinR::bytes_to_words64(blk, ofs, w, 0, wcnt)
      for i in 0..wcnt-1
        x[i] = SkeinR::add64(w[i], ks[i])
      end
      x[wcnt - 3] = SkeinR::add64(x[wcnt - 3], ts[0])
      x[wcnt - 2] = SkeinR::add64(x[wcnt - 2], ts[1])
      #SkeinR::dbgf("after initkinj: %s", SkeinR::words64_to_hex(x, 0, x.length, x.length))
      for r in 1..ROUNDS_TOTAL/8
        x[ 0] = SkeinR::add64(x[ 0], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_0_0); x[ 1] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_0_1); x[ 3] ^= x[ 2]
        x[ 4] = SkeinR::add64(x[ 4], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_0_2); x[ 5] ^= x[ 4]
        x[ 6] = SkeinR::add64(x[ 6], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_0_3); x[ 7] ^= x[ 6]
        x[ 8] = SkeinR::add64(x[ 8], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_0_4); x[ 9] ^= x[ 8]
        x[10] = SkeinR::add64(x[10], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_0_5); x[11] ^= x[10]
        x[12] = SkeinR::add64(x[12], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_0_6); x[13] ^= x[12]
        x[14] = SkeinR::add64(x[14], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_0_7); x[15] ^= x[14]; #SkeinR::dbgf("after round %2d: %s", r*8-7, SkeinR::words64_to_hex(x, 0, x.length, x.length))

        x[ 0] = SkeinR::add64(x[ 0], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_1_0); x[ 9] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_1_1); x[13] ^= x[ 2]
        x[ 6] = SkeinR::add64(x[ 6], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_1_2); x[11] ^= x[ 6]
        x[ 4] = SkeinR::add64(x[ 4], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_1_3); x[15] ^= x[ 4]
        x[10] = SkeinR::add64(x[10], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_1_4); x[ 7] ^= x[10]
        x[12] = SkeinR::add64(x[12], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_1_5); x[ 3] ^= x[12]
        x[14] = SkeinR::add64(x[14], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_1_6); x[ 5] ^= x[14]
        x[ 8] = SkeinR::add64(x[ 8], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_1_7); x[ 1] ^= x[ 8]; #SkeinR::dbgf("after round %2d: %s", r*8-6, SkeinR::words64_to_hex(x, 0, x.length, x.length))

        x[ 0] = SkeinR::add64(x[ 0], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_2_0); x[ 7] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_2_1); x[ 5] ^= x[ 2]
        x[ 4] = SkeinR::add64(x[ 4], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_2_2); x[ 3] ^= x[ 4]
        x[ 6] = SkeinR::add64(x[ 6], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_2_3); x[ 1] ^= x[ 6]
        x[12] = SkeinR::add64(x[12], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_2_4); x[15] ^= x[12]
        x[14] = SkeinR::add64(x[14], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_2_5); x[13] ^= x[14]
        x[ 8] = SkeinR::add64(x[ 8], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_2_6); x[11] ^= x[ 8]
        x[10] = SkeinR::add64(x[10], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_2_7); x[ 9] ^= x[10]; #SkeinR::dbgf("after round %2d: %s", r*8-5, SkeinR::words64_to_hex(x, 0, x.length, x.length))

        x[ 0] = SkeinR::add64(x[ 0], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_3_0); x[15] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_3_1); x[11] ^= x[ 2]
        x[ 6] = SkeinR::add64(x[ 6], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_3_2); x[13] ^= x[ 6]
        x[ 4] = SkeinR::add64(x[ 4], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_3_3); x[ 9] ^= x[ 4]
        x[14] = SkeinR::add64(x[14], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_3_4); x[ 1] ^= x[14]
        x[ 8] = SkeinR::add64(x[ 8], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_3_5); x[ 5] ^= x[ 8]
        x[10] = SkeinR::add64(x[10], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_3_6); x[ 3] ^= x[10]
        x[12] = SkeinR::add64(x[12], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_3_7); x[ 7] ^= x[12]; #SkeinR::dbgf("after round %2d: %s", r*8-4, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        inject_key(2 * r - 1, wcnt, x, ks, ts)                                                       ; #SkeinR::dbgf("after keyinj#1: %s" ,        SkeinR::words64_to_hex(x, 0, x.length, x.length))

        x[ 0] = SkeinR::add64(x[ 0], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_4_0); x[ 1] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_4_1); x[ 3] ^= x[ 2]
        x[ 4] = SkeinR::add64(x[ 4], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_4_2); x[ 5] ^= x[ 4]
        x[ 6] = SkeinR::add64(x[ 6], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_4_3); x[ 7] ^= x[ 6]
        x[ 8] = SkeinR::add64(x[ 8], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_4_4); x[ 9] ^= x[ 8]
        x[10] = SkeinR::add64(x[10], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_4_5); x[11] ^= x[10]
        x[12] = SkeinR::add64(x[12], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_4_6); x[13] ^= x[12]
        x[14] = SkeinR::add64(x[14], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_4_7); x[15] ^= x[14]; #SkeinR::dbgf("after round %2d: %s", r*8-3, SkeinR::words64_to_hex(x, 0, x.length, x.length))

        x[ 0] = SkeinR::add64(x[ 0], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_5_0); x[ 9] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_5_1); x[13] ^= x[ 2]
        x[ 6] = SkeinR::add64(x[ 6], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_5_2); x[11] ^= x[ 6]
        x[ 4] = SkeinR::add64(x[ 4], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_5_3); x[15] ^= x[ 4]
        x[10] = SkeinR::add64(x[10], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_5_4); x[ 7] ^= x[10]
        x[12] = SkeinR::add64(x[12], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_5_5); x[ 3] ^= x[12]
        x[14] = SkeinR::add64(x[14], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_5_6); x[ 5] ^= x[14]
        x[ 8] = SkeinR::add64(x[ 8], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_5_7); x[ 1] ^= x[ 8]; #SkeinR::dbgf("after round %2d: %s", r*8-2, SkeinR::words64_to_hex(x, 0, x.length, x.length))

        x[ 0] = SkeinR::add64(x[ 0], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_6_0); x[ 7] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_6_1); x[ 5] ^= x[ 2]
        x[ 4] = SkeinR::add64(x[ 4], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_6_2); x[ 3] ^= x[ 4]
        x[ 6] = SkeinR::add64(x[ 6], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_6_3); x[ 1] ^= x[ 6]
        x[12] = SkeinR::add64(x[12], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_6_4); x[15] ^= x[12]
        x[14] = SkeinR::add64(x[14], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_6_5); x[13] ^= x[14]
        x[ 8] = SkeinR::add64(x[ 8], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_6_6); x[11] ^= x[ 8]
        x[10] = SkeinR::add64(x[10], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_6_7); x[ 9] ^= x[10]; #SkeinR::dbgf("after round %2d: %s", r*8-1, SkeinR::words64_to_hex(x, 0, x.length, x.length))

        x[ 0] = SkeinR::add64(x[ 0], x[15]); x[15] = SkeinR::rotl64(x[15], R1024_7_0); x[15] ^= x[ 0]
        x[ 2] = SkeinR::add64(x[ 2], x[11]); x[11] = SkeinR::rotl64(x[11], R1024_7_1); x[11] ^= x[ 2]
        x[ 6] = SkeinR::add64(x[ 6], x[13]); x[13] = SkeinR::rotl64(x[13], R1024_7_2); x[13] ^= x[ 6]
        x[ 4] = SkeinR::add64(x[ 4], x[ 9]); x[ 9] = SkeinR::rotl64(x[ 9], R1024_7_3); x[ 9] ^= x[ 4]
        x[14] = SkeinR::add64(x[14], x[ 1]); x[ 1] = SkeinR::rotl64(x[ 1], R1024_7_4); x[ 1] ^= x[14]
        x[ 8] = SkeinR::add64(x[ 8], x[ 5]); x[ 5] = SkeinR::rotl64(x[ 5], R1024_7_5); x[ 5] ^= x[ 8]
        x[10] = SkeinR::add64(x[10], x[ 3]); x[ 3] = SkeinR::rotl64(x[ 3], R1024_7_6); x[ 3] ^= x[10]
        x[12] = SkeinR::add64(x[12], x[ 7]); x[ 7] = SkeinR::rotl64(x[ 7], R1024_7_7); x[ 7] ^= x[12]; #SkeinR::dbgf("after round %2d: %s", r*8-0, SkeinR::words64_to_hex(x, 0, x.length, x.length))
        inject_key(2 * r, wcnt, x, ks, ts)                                                           ; #SkeinR::dbgf("after keyinj#2: %s" ,        SkeinR::words64_to_hex(x, 0, x.length, x.length))
      end
      for i in 0..wcnt-1
        @X[i] = x[i] ^ w[i]
      end                                                                                            ; #SkeinR::dbgf("after ptxtfdfw: %s", SkeinR::words64_to_hex(@X, 0, @X.length, @X.length))
      @T[1] &= ~BIT_FIRST
    end
  end

##############################################################################

  def SkeinR::hash_string(str, hash = SkeinR::Hash512.new)
    hash.update_str str
    res = hash.final
    SkeinR::bytes_to_hex res, 0, res.length
  end

  def SkeinR::hash_file(fname, hash = SkeinR::Hash512.new)
    File.open(fname) do |fl|
      fl.each_byte do |byte|
        hash.update byte
      end
    end
    res = hash.final
    SkeinR::bytes_to_hex res, 0, res.length
  end
end
