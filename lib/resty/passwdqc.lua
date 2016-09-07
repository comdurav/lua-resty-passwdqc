local ffi = require "ffi"
local ffi_cdef = ffi.cdef
local ffi_load = ffi.load
local ffi_typeof = ffi.typeof
local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local C = ffi.C
local setmetatable = setmetatable

ffi_cdef[[
typedef struct {
	int min[5], max;
	int passphrase_words;
	int match_length;
	int similar_deny;
	int random_bits;
} passwdqc_params_qc_t;
typedef struct {
	int flags;
	int retry;
} passwdqc_params_pam_t;
typedef struct {
	passwdqc_params_qc_t qc;
	passwdqc_params_pam_t pam;
} passwdqc_params_t;
const char *passwdqc_check(const passwdqc_params_qc_t *params, const char *newpass, const char *oldpass, const struct passwd *pw);
char *passwdqc_random(const passwdqc_params_qc_t *params);
int passwdqc_params_parse(passwdqc_params_t *params, char **reason, int argc, const char *const *argv);
int passwdqc_params_load(passwdqc_params_t *params, char **reason, const char *pathname);
void passwdqc_params_reset(passwdqc_params_t *params);
void (*_passwdqc_memzero)(void *, size_t);
void free(void *ptr);
]]

local lib = ffi_load "passwdqc"
local pct = ffi_typeof "passwdqc_params_t"
local cct = ffi_typeof "const char*[?]"
local rpt = ffi_typeof "char *[?]"

local defaults = {
    min = "disabled,24,11,8,7",
    max = 40,
    passphrase = 3,
    match = 4,
    similar = "deny",
    random = 47,
}

local function init()
    local pt = ffi_new(pct)
    lib.passwdqc_params_reset(pt)
    return pt
end

local function parse(context, opts)
    if opts then
        local argv = {
            "min="        .. (opts.min        or defaults.min),
            "max="        .. (opts.max        or defaults.max),
            "passphrase=" .. (opts.passphrase or defaults.passphrase),
            "match="      .. (opts.match      or defaults.match),
            "similar="    .. (opts.similar    or defaults.similar),
            "random="     .. (opts.random     or defaults.random)
        }
        local argv = ffi_new(cct, 6, argv)
        local rson = ffi_new(rpt, 100)
        lib.passwdqc_params_parse(context, rson, 6, argv)
    end
    return context
end

local function random(context, opts)
    parse(context, opts)
    local pw = ffi_gc(lib.passwdqc_random(context.qc), C.free)
    local ps = ffi_str(pw)
    lib._passwdqc_memzero(pw, #ps)
    return ps
end

local function check(context, newpass, oldpass, opts)
    parse(context, opts)
    local rs = lib.passwdqc_check(context.qc, newpass, oldpass, nil)
    if rs == nil then
        return true
    end
    return nil, ffi_str(rs)
end

local mt = {}

function mt:random(opts)
    return random(self.context, opts)
end

function mt:check(newpass, oldpass, opts)
    return check(self.context, newpass, oldpass, opts)
end

local passwdqc = {}

function passwdqc.new(opts)
    return setmetatable({ context = parse(init(), opts) }, mt)
end

function passwdqc.random(opts)
    return random(init(), opts)
end

function passwdqc.check(newpass, oldpass, opts)
    return check(init(), newpass, oldpass, opts)
end

return passwdqc