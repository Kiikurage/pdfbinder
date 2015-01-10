//
//  Image.h
//  pdfbinder
//
//  Created by kikurage on 2014/11/08.
//  Copyright (c) 2014年 KikuraYuichiro. All rights reserved.
//

#ifndef __pdfbinder__Image__
#define __pdfbinder__Image__

#include <stdlib.h>
#include <string.h>

typedef struct {
	unsigned char r;
	unsigned char g;
	unsigned char b;
} Color;

typedef struct {
	int x;
	int y;
} Pos;

typedef struct {
	int t;
	int r;
	Pos p1;
	Pos p2;
} Line;

typedef struct {
	Pos p1;
	Pos p2;
	Pos p3;
	Pos p4;
} Square;

class Image
{
private:
	
public:
	unsigned char *data;
	unsigned int width;
	unsigned int height;
	
	Image(unsigned int width, unsigned int height);
	~Image();
	Image* copy();
	unsigned char getR(unsigned int x, unsigned int y);
	unsigned char getG(unsigned int x, unsigned int y);
	unsigned char getB(unsigned int x, unsigned int y);
	void setR(unsigned int x, unsigned int y, unsigned char value);
	void setG(unsigned int x, unsigned int y, unsigned char value);
	void setB(unsigned int x, unsigned int y, unsigned char value);
	unsigned char get(unsigned int x, unsigned int y);
	void set(unsigned int x, unsigned int y, unsigned char value);
};

#endif /* defined(__pdfbinder__Image__) */
