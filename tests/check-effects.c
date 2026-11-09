#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "argparser.h"
#include "rgbmodes.h"
int main(void) {
 const char *modes[] = {"solid", "pulse", "blink", "cycle"};
 int tests = 0;
 for(int m=0;m<4;m++) for(int speed=1;speed<=100;speed++) for(int b=0;b<=100;b+=50) {
  char sp[8],br[8],delay[8]; snprintf(sp,8,"%d",speed); snprintf(br,8,"%d",b); snprintf(delay,8,"%d",101-speed);
  const char *args[11] = {"check",modes[m]}; int argc=2;
  if(m!=3) args[argc++]="8844ff";
  args[argc++]="-s"; args[argc++]=sp; args[argc++]="-b"; args[argc++]=br;
  if(m==2) { args[argc++]="-d"; args[argc++]=delay; }
  struct colschemes cs = {0}; int verbose=0,count=0;
  parse_arg(&cs,argc,args,&verbose); cs.pid=0x171f;
  datpack *data=parse_colorscheme(&cs,&count);
  assert(data && count>0 && count<=MAX_PCT_COUNT);
  assert(count_color_commands(data,count,0)>0);
  free(data); tests++;
 }
 printf("OK: %d combinations of effect, speed, and brightness.\n",tests);
}
