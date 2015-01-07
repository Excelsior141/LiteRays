import derelict.sdl2.sdl;
import math;
import core.time;
import std.stdio;
import std.random;
import std.conv;
import std.math;
import std.parallelism;
import std.range;

enum windowWidth = 1024;
enum windowHeight = 800;
enum screenWidth =  windowWidth  ;
enum screenHeight = windowHeight ;
enum loopWidth = screenWidth     /2;
enum loopHeight = screenHeight   /2;
enum PI = 3.14159265359;
enum PI_2 = PI * 2;
int frames = 0;
static threads = [1,2,3,4];

struct Pixel {
	ubyte b;
	ubyte g;
	ubyte r;
	ubyte a;
}

Pixel toUb(Vec color) {
	return Pixel(cast(ubyte)(pow(clamp(color.z, 0f, 1f), 1/2.2) * 255 + 0.5),
				 cast(ubyte)(pow(clamp(color.y, 0f, 1f), 1/2.2) * 255 + 0.5),
				 cast(ubyte)(pow(clamp(color.x, 0f, 1f), 1/2.2) * 255 + 0.5), 255);
}

float clamp(float x, float a, float b) {
	return float(x<a ? a : x>b ? b : x);
} 

void main() {

	DerelictSDL2.load();
	SDL_Init(SDL_INIT_VIDEO);

	auto window = SDL_CreateWindow("LiteRays", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, windowWidth, windowHeight, 0);
	scope(exit) SDL_DestroyWindow(window);

	auto renderer = SDL_CreateRenderer(window, -1, 0);
	scope(exit) SDL_DestroyRenderer(renderer);

	auto screen = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STATIC, screenWidth, screenHeight);
	scope(exit) SDL_DestroyTexture(screen);

	auto pixels = new Pixel[screenWidth * screenHeight];
	auto allColors = new Vec[screenWidth * screenHeight];

	auto workers = new TaskPool(4);

	foreach (i,pix;pixels) {
		allColors[i] = Vec();
	}

	auto running = true;

	auto firstTick = TickDuration.currSystemTick;
	auto prevTick = firstTick;

	Sphere spheres[];	
	spheres ~= Sphere(100, Vec(0,-101, 5), Vec(), Vec(0.75,0.75,0.75), Refl_t.DIFF);
	spheres ~= Sphere(1,   Vec(0.75, 0, 5), Vec(), Vec(0.75,0.25,0.25), Refl_t.DIFF);
	spheres ~= Sphere(1,   Vec(-0.75, 0, 5), Vec(), Vec(0.25,0.75,0.25), Refl_t.REFR);
	spheres ~= Sphere(1,   Vec(0, 1.5, 5), Vec(), Vec(0.75,0.75,0.75), Refl_t.SPEC);
	//spheres ~= Sphere(100,   Vec(0,0,5), Vec(), Vec(0.05,0.2,0.9), Refl_t.DIFF);
	spheres ~= Sphere(5,  Vec(0,50,75), Vec(500,500,125), Vec(), Refl_t.DIFF);

	Vec lightDir = (spheres[4].p * 100000).norm();
	Vec lightColor = Vec(1,1,0.25);

	bool intersect(Ray r, ref float t, ref int id, int os){
  		float d, inf=t=1e20;
  		for(int i=cast(int)spheres.length;i--;) {
  			if (os != -1) {
  				if (spheres[i] == spheres[os]) {
  					continue;
  				}
  			}
  			d = spheres[i].intersect(r);
  			if(d>0 && d<t){
  				t=d;
  				id=i;
  			}
  		}
  	return t<inf;
  	}

	void clearScreen()
	{
		foreach (ref pixel; pixels)
			pixel = Pixel(0, 0, 0, 255);
	}

	void updateSamples() {
		foreach (i, ref pixel; pixels)
			pixel = toUb((allColors[i] / frames).clip);
	}

	void putPixel(int x, int y, Pixel pixel)
	{
		pixels[x + screenWidth * y] = pixel;
	}

	void addColor(int x, int y, Vec color)
	{
		allColors[x + screenWidth * y] = allColors[x + screenWidth * y] + color;
	}

	Vec radiance(Ray r, int depth, int os) {
  		float t;                             
    	int id=0;
    	if (!intersect(r, t, id, os)) {
    		Vec skyCol = Vec(0,0.25,0.5);
    		if (r.d.y > 0) {
					skyCol.y /= (r.d.normalTransform.y * 1.5f);
					skyCol.y = skyCol.y.clamp(0,0.5);
			} else {
					skyCol.y /= (r.d.normalTransform.y * 1.5f);
					skyCol.y = skyCol.y.clamp(0,0.5);
			}

			float sun = r.d.dot(lightDir);
			if (sun > 0) {
				sun = pow(sun, 10);
				skyCol = skyCol + (lightColor * sun);
			}

			return skyCol;
    	}
    	Vec x=r.o+r.d*t, n=(x-spheres[id].p).norm(), nl=n.dot(r.d)<0?n:n*-1, f=spheres[id].c; 
    	double p = f.x>f.y && f.x>f.z ? f.x : f.y>f.z ? f.y : f.z; // max refl 
    	if (++depth>5) {
    		if (uniform(0,1.0)<p) {
    			f=f*(1/p);
    		} else {
    			return spheres[id].e;
    		}
    	}
    	if (spheres[id].refl == Refl_t.DIFF) {                  // Ideal DIFFUSE reflection 
    	double r1=PI_2*uniform(0,1.0), r2=uniform(0,1.0), r2s=sqrt(r2); 
    	Vec w=nl, u=((fabs(w.x)>.1?Vec(0,1,0):Vec(1,0,0))%w).norm(), v=w%u; 
    	Vec d = (u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrt(1-r2)).norm(); 
    	return spheres[id].e + f.mult(radiance(Ray(x,d),depth, id));
    	} else if (spheres[id].refl == Refl_t.SPEC) {           // Ideal SPECULAR reflection 
    		return spheres[id].e + f.mult(radiance(Ray(x,r.d-n*2*n.dot(r.d)),depth, id));
    	}
    	Ray reflRay = Ray(x, r.d-n*2*n.dot(r.d));     // Ideal dielectric REFRACTION 
    	bool into = n.dot(nl)>0;                // Ray from outside going in? 
    	double nc=1, nt=1.5, nnt=into?nc/nt:nt/nc, ddn=r.d.dot(nl), cos2t; 
    	if ((cos2t=1-nnt*nnt*(1-ddn*ddn))<0) {    // Total internal reflection 
    		return spheres[id].e + f.mult(radiance(reflRay,depth, -1));
    	}
    	Vec tdir = (r.d*nnt - n*((into?1:-1)*(ddn*nnt+sqrt(cos2t)))).norm(); 
    	double a=nt-nc, b=nt+nc, R0=a*a/(b*b), c = 1-(into?-ddn:tdir.dot(n)); 
    	double Re=R0+(1-R0)*c*c*c*c*c,Tr=1-Re,P=.25+.5*Re,RP=Re/P,TP=Tr/(1-P); 
    	return spheres[id].e + f.mult(depth>2 ? (uniform(0,1.0)<P ? 
    	radiance(reflRay,depth, -1)*RP:radiance(Ray(x,tdir),depth, -1)*TP) : 
    	radiance(reflRay,depth, -1)*Re+radiance(Ray(x,tdir),depth, -1)*Tr);
    }
    




void render() {
		void processPixel(int x, int y, float camOffx, float camOffy)
		{
			auto ray = Ray(Vec(), Vec(camOffx + uniform(-0.5,0.5), camOffy + uniform(-0.5,0.5), 500).norm());
			addColor(x, y, radiance(ray, 1024, -1));
		}

		int Pixx = 0;
		int Pixy = 0;

		for(int camOffy = loopHeight; camOffy > -loopHeight; camOffy--) 
		{
		    for(int camOffx = -loopWidth; camOffx < loopWidth; camOffx++)
			{
				processPixel(Pixx, Pixy, camOffx, camOffy);
				Pixx++;
			}

			Pixx = 0;
			Pixy++;
		}
}

	while (running)
	{



    	foreach (i; workers.parallel(threads)) {
       		render();
   		}

    	

		SDL_Event event;

		if (SDL_PollEvent(&event))
			switch (event.type)
			{
				case SDL_QUIT:
					break;

				default:
			}

		auto currTick = TickDuration.currSystemTick;
		auto elapsed = (currTick - prevTick).to!("seconds", float);
		prevTick = currTick;

		auto keyState = SDL_GetKeyboardState(null);
		
		if (keyState[SDL_SCANCODE_Q]) {
			writeln("Average samples per second: ", frames  / ((currTick - firstTick).to!("seconds", float)));
			writeln("Samples: ", frames);
			writeln("Runtime: ", ((currTick - firstTick).to!("seconds", float))," seconds");
			running = false;
		}

		if (keyState[SDL_SCANCODE_U]) {
			updateSamples();
			SDL_UpdateTexture(screen, null, cast(ubyte*)pixels.ptr, screenWidth * Pixel.sizeof);
			SDL_RenderClear(renderer);
        	SDL_RenderCopy(renderer, screen, null, null);
        	SDL_RenderPresent(renderer);
		}
        frames += 4;
	}
	workers.finish();
}
