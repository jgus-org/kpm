#pragma once

#include <stdbool.h>

typedef struct {
  int row;
  int voffset;
  bool is_verbose;
  bool is_quiet;
  int wfm_mode;
  bool no_refresh;
  bool is_cleared;
  int fontmult;
} FBInkConfig;

typedef struct {
  int fontsize_mult;
  int screen_width;
  int screen_height;
} FBInkState;

typedef struct {
  int left;
  int top;
  int width;
  int height;
} FBInkRect;

enum {
  WFM_AUTO,
};

int fbink_open(void);
int fbink_init(int framebuffer, FBInkConfig* config);
int fbink_get_state(const FBInkConfig* config, FBInkState* state);
int fbink_cls(int framebuffer, const FBInkConfig* config, const FBInkRect* rect, bool no_refresh);
int fbink_refresh(int framebuffer, int left, int top, int width, int height, const FBInkConfig* config);
int fbink_close(int framebuffer);
int fbink_print(int framebuffer, const char* string, FBInkConfig* config);
