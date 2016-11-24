/*
 * Connect the dots -- maze solver
 *
 * Designed by Eli Baum, 2015, for the 21st Leonardo Challenge.
 *
 */
 
 
// TODO
// Stats on solver:
// time
// size of frontier + visited
// distance to target

import processing.video.*;
import java.util.PriorityQueue;
import java.util.HashMap;
import java.util.Set;
import java.util.Comparator;

/* ==== final fields ==== */

/* Brightness threshold for webcam
 * May need to be adjusted based on lighting conditions.
 */
final int camThreshold = 64;

/* Dimensions are camera specific. */
final int videoWidth = 640;
final int videoHeight = 480;

final color BLACK = color(0);
final color WHITE = color(255);

/* Number of iterations to run in mazeRunner()
 * Too high, and the fast parts are too fast.
 * Too low, and the slow parts are too slow.
 */
final int ITERATIONS = 70;

/* For text padding. */
final int PAD = 20;


PImage title;
State state = State.title;

PFont helv;

Capture video;

/* The webcam image will be drawn into here so that
 * it can be scaled and moved.
 */
PGraphics maze;

/* Actually used for drawing stuff.
 */
PGraphics mg;

/* For adjusting absolute mouse coords to relative coords.
 */
int widthAdj, heightAdj;

PVector start, end;
Comparator<PVector> comp = new HeuristicDistance(); // class definition @ bottom
PriorityQueue<PVector> frontier = new PriorityQueue<PVector>(1, comp);
HashMap<PVector, PVector> from = new HashMap<PVector, PVector>();

color startColor;


void setup()
{
  title = loadImage("title.png");

  helv = loadFont("Helvetica.vlw");
  textFont(helv);
  textAlign(CENTER, CENTER);

  size(title.width, title.height);

  video = new Capture(this, videoWidth, videoHeight, "Microsoft LifeCam-VX700  v2.0");
  maze = createGraphics(videoWidth, videoHeight);
  mg = createGraphics(videoWidth, videoHeight);

  widthAdj = (width - videoWidth) / 2;
  heightAdj = (height - videoHeight) / 2;

  imageMode(CENTER);
}

void draw()
{

  if (state == State.title)
  {
    image(title, width / 2, height / 2);
    noLoop(); // wait until mouse click
  }
  //

  else if (state == State.scan)
  {
    if (video.available())
    {
      background(0);
      textAlign(CENTER, CENTER);
      text("Place the maze into the scanning area.", 0, 0, width, heightAdj);
      textAlign(RIGHT, BOTTOM);
      text("Click to save and continue...", 0, 0, width - PAD, height - PAD); 
      video.read();
      video.loadPixels();
      maze.loadPixels();
      for (int i = 0; i < videoWidth * videoHeight; i++) {
        // Don't include the blue value because it's too noisy.
        if ((red(video.pixels[i]) + green(video.pixels[i])) / 2 > camThreshold) {
          maze.pixels[i] = WHITE;
        } else {
          maze.pixels[i] = BLACK;
        }
      }
      maze.updatePixels();

      image(maze, width / 2, height / 2);
    }
  }
  //

  else if (state == State.startPoint)
  {
    background(0);
    textAlign(CENTER, CENTER);
    text("Choose the start point.", 0, 0, width, heightAdj);
    image(maze, width / 2, height / 2);
  }
  //

  else if (state == State.endPoint)
  {
    background(0);
    textAlign(CENTER, CENTER);
    text("Choose the end point.", 0, 0, width, heightAdj);
    mg.beginDraw();
    // draw start point
    mg.strokeWeight(7);
    mg.stroke(255, 0, 0);
    mg.point(start.x, start.y);
    mg.endDraw();
    image(maze, width / 2, height / 2);
    image(mg, width / 2, height / 2);
  }
  //

  else if (state == State.solving)
  {
    background(0);
    textAlign(CENTER, CENTER);
    text("Solving...", 0, 0, width, heightAdj);

    mazeRunner();

    mg.beginDraw();
    mg.loadPixels();
    color fill = color(230, 230, 230);
    Set<PVector> s = from.keySet();
    for (PVector p : s)
    {
      mg.pixels[(int) (p.x + mg.width * p.y)] = fill;
    }
    fill = color(127, 127, 127);
    for (PVector p : frontier)
    {
      mg.pixels[(int) (p.x + mg.width * p.y)] = fill;
    }
    mg.updatePixels();

    mg.strokeWeight(7);
    mg.stroke(255, 0, 0);
    mg.point(start.x, start.y);

    mg.stroke(0, 255, 0);
    mg.point(end.x, end.y);

    mg.endDraw();

    image(maze, width / 2, height / 2);
    image(mg, width / 2, height / 2);
  }
  //

  else if (state == State.trace)
  {
    mg.beginDraw();
    mg.strokeWeight(3);
    mg.stroke(0, 0, 255);
    PVector q = end;
    while (! q.equals (start))
    {
      q = from.remove(q);
      mg.point(q.x, q.y);
    }

    mg.strokeWeight(7);
    mg.stroke(255, 0, 0);
    mg.point(start.x, start.y);

    mg.stroke(0, 255, 0);
    mg.point(end.x, end.y);

    mg.endDraw();
    image(mg, width / 2, height / 2);
    state = State.found;
  }
  //

  else if (state == State.found)
  { 
    background(0);
    image(maze, width / 2, height / 2);
    image(mg, width / 2, height / 2);
    text("Found a path!", 0, 0, width, heightAdj);
    textAlign(RIGHT, BOTTOM);
    text("Click to restart...", 0, 0, width - PAD, height - PAD); 

    noLoop();
  }
  //

  else if (state == State.notFound)
  {
    background(0);
    image(maze, width / 2, height / 2);
    image(mg, width / 2, height / 2);
    text("No path found.", 0, 0, width, heightAdj);
    textAlign(RIGHT, BOTTOM);
    text("Click to restart...", 0, 0, width - PAD, height - PAD); 

    noLoop();
  }
}

void mousePressed()
{
  if (state == State.title)
  {
    state = State.loading;
    background(0);
    textAlign(CENTER, CENTER);
    text("camera loading...", 0, 0, width, height);

    // OH YEAH asynchronous webcam boot
    new Thread(new Runnable() {
      public void run() {
        video.start();
        state = State.scan;
      }
    }
    ).start();

    loop();
  } else if (state == State.scan)
  {
    // maze now contains a still frame of the maze.
    video.stop();
    state = State.startPoint;
  } else if (state == State.startPoint)
  {
    start = new PVector(mouseX - widthAdj, mouseY - heightAdj);
    state = State.endPoint;
  } else if (state == State.endPoint)
  {
    end = new PVector(mouseX - widthAdj, mouseY - heightAdj);
    state = State.solving;

    startColor = maze.get((int) start.x, (int) start.y);
    frontier.add(start);
    from.put(start, null); // Start didn't come from anywhere; it maps to null
  } else if (state == State.found || state == State.notFound)
  { 
    // restart everything
    state = State.title;
    
    frontier.clear();
    from.clear();
    
    maze.clear();
    mg.clear();
    
    loop();
  }
}

/* For checking the current point's (frm)
 * neighbors (to).
 * If the point is clear (i.e. not already visisted and not a boundary),
 * it is added to the frontier and from map.
 */
void check(PVector to, PVector frm)
{
  if (! from.containsKey(to) && (maze.get((int) to.x, (int) to.y) == startColor))
  {
    frontier.add(to);
    from.put(to, frm);
  }
}

void mazeRunner()
{
  for (int c = 0; c < ITERATIONS; c++)
  {
    PVector p = frontier.remove();
    if (p.equals(end))
    {
      println("found");
      state = State.trace;
      return;
    }

    check(new PVector(p.x + 1, p.y), p);
    check(new PVector(p.x - 1, p.y), p);
    check(new PVector(p.x, p.y + 1), p);
    check(new PVector(p.x, p.y - 1), p);

    if (frontier.isEmpty())
    {
      println("not found");
      state = State.notFound;
      return;
    }
  }
}

public class HeuristicDistance implements Comparator<PVector>
{
  public int compare(PVector a, PVector b)
  {
    /* Returns Manhattan distance difference
     * between the two points and the end point.
     */
    return (int) ((abs(a.x - end.x) + abs(a.y - end.y)) -
      (abs(b.x - end.x) + abs(b.y - end.y)));
  }
}

