#include "libre2_mojo.h"

static_assert(sizeof(re2m_string_t) == 16,
              "re2m_string_t must be 16 bytes (LP64 only in V0)");
