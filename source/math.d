module math;
import std.math;
import std.conv;
import std.traits;

enum Refl_t { DIFF, SPEC, REFR };

struct Vec {      
 	float x = 0;
    float y = 0;
    float z = 0;

	this(float x, float y, float z) {
  		this.x = x;
  		this.y = y;
  		this.z = z;
	}

	Vec opBinary(string op)(Vec other)
    	if (op == "+" || op == "-" || op == "%")
    {
        Vec result;
        static if (op == "%") {
        	result.x = (this.y * other.z) - (this.z * other.y);
        	result.y = (this.z * other.x) - (this.x * other.z);
        	result.z = (this.x * other.y) - (this.y * other.x);
        } else {
	        result.x = mixin("this.x" ~ op ~ "other.x");
	        result.y = mixin("this.y" ~ op ~ "other.y");
			result.z = mixin("this.z" ~ op ~ "other.z");
		}
        return result;
    }

	Vec opBinary(string op)(float scalar)
        if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        Vec result;
        result.x = mixin("this.x" ~ op ~ "scalar");
        result.y = mixin("this.y" ~ op ~ "scalar");
        result.z = mixin("this.z" ~ op ~ "scalar");
        return result;
    }

    Vec mult(Vec other) {
    	Vec result;
    	result.x = this.x * other.x;
    	result.y = this.y * other.y;
    	result.z = this.z * other.z;
    	return result;
    }

    float dot(Vec other) {
    	float result;
    	result = this.x * other.x + this.y * other.y + this.z * other.z;
    	return result;
    }

    Vec norm() {
    	Vec result;
        result = this * (1/sqrt(this.x*this.x + this.y*this.y + this.z*this.z));
    	return result;
    }

    Vec clamp(float a, float b) {
        this.x = (this.x<a ? a : this.x>b ? b : this.x);
        this.y = (this.y<a ? a : this.y>b ? b : this.y);
        this.z = (this.z<a ? a : this.z>b ? b : this.z);
        return this;
    }

    Vec normalTransform() {
        return Vec((this.x * 0.5) + 0.5, (this.y * 0.5) + 0.5, (this.z * 0.5) + 0.5);
    }

    Vec clip() {

        float alllight = this.x + this.y + this.z;
        float excesslight = alllight - 3;

        if (excesslight > 0) {
            this.x = this.x + excesslight * (this.x / alllight);
            this.y = this.y + excesslight * (this.y / alllight);
            this.z = this.z + excesslight * (this.z / alllight);
        }

        this = this.clamp(0,1);
        
        return Vec(this.x, this.y, this.z);
    }
}

struct Ray {
	Vec o, d;

	this(Vec o, Vec d) {
		this.o = o;
		this.d = d;
	}
}

struct Sphere {
	float rad;      
	Vec p = Vec();
    Vec e = Vec();
    Vec c = Vec();     
	Refl_t refl;

	this(float rad, Vec p, Vec e, Vec c, Refl_t refl) {
		this.rad = rad;
		this.p = p;
		this.e = e;
		this.c = c;
		this.refl = refl;
	}

	float intersect(ref Ray r) {
	    Vec op = this.p-r.o;
	    float t, eps=float.epsilon, b=op.dot(r.d), det=b*b-op.dot(op)+rad*rad;
	    if (det<0) {
            return 0;
        } else {
            det=sqrt(det);
        }
	    return (t=b-det)>eps ? t : ((t=b+det)>eps ? t : 0);
	}
}

struct Polygon {

	Vec vertices[3] = [Vec(), Vec(), Vec()];
    Vec e = Vec();
    Vec c = Vec();     
	Refl_t refl;

	this(Vec vertices[3], Vec e, Vec c, Refl_t refl) {
		this.vertices = vertices;
		this.e = e;
		this.c = c;
		this.refl = refl;
	}

	bool intersect(Ray r, Vec v[3], out float distance)
	{
	    auto edge1 = v[1] - v[0];
	    auto edge2 = v[2] - v[0];

	    auto dc = r.o % edge2;
	    auto d = edge1.dot(dc);

	    if (d < float.epsilon && d > -float.epsilon)
	        return false;

	    auto vec = r.o - v[0];
	    auto uvU = vec.dot(dc) / d;

	    if (uvU < 0 || uvU > 1)
	        return false;

	    dc = vec % edge1;
	    auto uvV = r.d.dot(dc) / d;

	    if (uvV < 0 || uvU + uvV > 1)
	        return false;

	    distance = edge2.dot(dc) / d;

	    if (distance < 0)
	        return false;

	    return true;
	}
}
