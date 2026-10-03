#ifndef INTERVIEW_PILOT_SYNTAX_H
#define INTERVIEW_PILOT_SYNTAX_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif
typedef struct IPSyntaxBuffer {
    const uint8_t *bytes;
    uintptr_t length;
} IPSyntaxBuffer;

// appearance: 0 = light, 1 = dark. Returns {NULL, 0} for rejected input or
// an internal error. The caller must release every non-null result exactly once.
IPSyntaxBuffer ip_syntax_highlight(
    const uint8_t *source,
    uintptr_t source_length,
    const uint8_t *language,
    uintptr_t language_length,
    uint8_t appearance
);

void ip_syntax_buffer_free(IPSyntaxBuffer buffer);

#ifdef __cplusplus
}
#endif

#endif
