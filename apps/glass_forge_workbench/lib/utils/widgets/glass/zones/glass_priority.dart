/// Which glass wins where two kit layers overlap.
///
/// Only one backdrop pass may cover any point on screen: a shader backdrop
/// filter painted above another overlapping one reads a stale previous frame,
/// including its own output, on physical iPhones (flutter#187820). Where two
/// layers meet, the lower priority renders static.
enum GlassPriority { content, chrome, overlay }
