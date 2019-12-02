module dtl.imgui_widgets;

static import neobc;
import dtoavkbindings.cimgui;

void igWidgetShowFramerateGraph(float delta)
{
  static neobc.Array!float storedDelta;
  static bool pauseGraph = false;
  static float storedCountdown = 0.0f;
  if (storedDelta.length == 0) storedDelta = neobc.Array!float(250);

  storedCountdown -= delta;

  // shift elements
  if (!pauseGraph && storedCountdown < 0.0f)
  {
    storedCountdown = 11.111f;
    for (size_t i = storedDelta.length-1; i != 0; -- i)
      storedDelta[i] = storedDelta[i-1];
    storedDelta[0] = delta;
  }

  float avg = 0.0f;
  float max = 0.0f;
  foreach (i; storedDelta.AsRange) {
    avg += i;
    if (i > max) max = i;
  }
  avg /= cast(float)storedDelta.length;

  igPlotLines(
    "\0"
  , storedDelta.ptr, cast(int)storedDelta.length
  , 0, "\0"
  , 0.0f, 11.111f
  , ImVec2(640, 50), 4
  );

  igText(
    "%.3f ms, %d FPS || avg %.3f ms, %d FPS",
    delta, cast(int)(1000.0f / delta),
    avg, cast(int)(1000.0f / avg)
  );

  igCheckbox("pause graph", &pauseGraph);

  foreach (i; storedDelta.AsRange) {
    if (i > 11.111f) {
      igTextColored(
        ImVec4(1.0f, 0.2f, 0.2f, 1.0f),
        "Bad frame encountered: %f", i
      );
    }
  }
}
