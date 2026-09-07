#include "fbink.h"

int fbink_open(void)
{
  return 0;
}

int fbink_init(int framebuffer, FBInkConfig* config)
{
  return 0;
}

int fbink_get_state(const FBInkConfig* config, FBInkState* state)
{
  state->fontsize_mult = 1;
  state->screen_width = 0;
  state->screen_height = 0;
  return 0;
}

int fbink_cls(int framebuffer, const FBInkConfig* config, const FBInkRect* rect, bool no_refresh)
{
  return 0;
}

int fbink_refresh(int framebuffer, int left, int top, int width, int height, const FBInkConfig* config)
{
  return 0;
}

int fbink_close(int framebuffer)
{
  return 0;
}

int fbink_print(int framebuffer, const char* string, FBInkConfig* config)
{
  return 1;
}
