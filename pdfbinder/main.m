	//
	//  main.cpp
	//  pdfbinder
	//
	//  Created by KikuraYuichiro on 2014/11/03.
	//  Copyright (c) 2014年 KikuraYuichiro. All rights reserved.
	//

#include <Cocoa/Cocoa.h>
#include <math.h>
#include <stdlib.h>

#define EPS 4
#define THETA_MAX 2048
#undef LINE_MAX
#define LINE_MAX 30
#define EDGE_MAX 4

typedef struct {
	int t;
	int r;
	int v;
} Line;

typedef struct {
	int x;
	int y;
} Pos;

typedef struct {
	Pos p1;
	Pos p2;
	Pos p3;
	Pos p4;
} Square;

int OUTPUT_WIDTH;
int OUTPUT_HEIGHT;

void save(NSData *data, NSString *path)
{
	[data writeToFile:path atomically:NO];
}

NSBitmapImageRep* convertToImageRep(NSImage *image)
{
	NSData *tiffData = [image TIFFRepresentation];
	NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:tiffData];
	
	return imageRep;
}

NSBitmapImageRep* greyscale(NSBitmapImageRep *input, const int width, const int height)
{
	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*3 bitsPerPixel:24];
	
	const NSInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];
	
	int grey;
	
	for (int y = 1; y < height-1; y++)
	{
		for (int x = 1; x < width-1; x++)
		{
			grey = (inputPix[y * inputRowBytes + 3*x] * 2
					+ inputPix[y * inputRowBytes + 3*x + 1] * 4
					+inputPix[y * inputRowBytes + 3*x + 2]) / 7;
			
			outputPix[y * outputRowBytes + 3*x] = (unsigned char)grey;
			outputPix[y * outputRowBytes + 3*x + 1] = (unsigned char)grey;
			outputPix[y * outputRowBytes + 3*x + 2] = (unsigned char)grey;
		}
	}
	
	return output;
}

int detectThreshold(int arr[], const int ARR_SIZE)
{
		//大津のアルゴリズム
	float maxSigma = 0, maxSigmaIndex = 0;
	float sigma;
	int n1 = 0, n2 = 0, s1 = 0, s2 = 0;
	
		//n:画素数 s:画素値の合計
	
	for (int i = 0; i < ARR_SIZE; i++) {
		n2 += arr[i];
		s2 += arr[i]*i;
	}
	
	for (int i = 0; i < ARR_SIZE; i++) {
		sigma = 1.0 * n1 * n2 * pow(1.0*s1/n1-1.0*s2/n2, 2) / pow(n1+n2, 2);
		
		if (sigma > maxSigma) {
			maxSigma = sigma;
			maxSigmaIndex = i;
		}
		
		n1 += arr[i];
		n2 -= arr[i];
		s1 += arr[i] * i;
		s2 -= arr[i] * i;
	}
	
	return maxSigmaIndex;
}

NSBitmapImageRep* monochrome(NSBitmapImageRep *input, const int width, const int height)
{
	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*3 bitsPerPixel:24];
	
	const NSInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];

	int arrBrightness[64];//幅4で64段階
	unsigned char r, g, b;

	for (int i = 0; i < 64; i++) arrBrightness[i] = 0;
	
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			r = inputPix[y*inputRowBytes + 3*x];
			g = inputPix[y*inputRowBytes + 3*x + 1];
			b = inputPix[y*inputRowBytes + 3*x + 2];
			arrBrightness[(r*2+g*4+b)/7/4]++;
		}
	}
	int threshold = detectThreshold(arrBrightness, 64);
	
	for (int y = 1; y < height; y++) {
		for (int x = 1; x < width; x++) {
			r = inputPix[y*inputRowBytes + 3*x];
			g = inputPix[y*inputRowBytes + 3*x + 1];
			b = inputPix[y*inputRowBytes + 3*x + 2];
			
			if ((r*2+g*4+b)/7 < threshold*4) {
				outputPix[y*outputRowBytes + 3*x] = 0;
				outputPix[y*outputRowBytes + 3*x + 1] = 0;
				outputPix[y*outputRowBytes + 3*x + 2] = 0;
			} else {
				outputPix[y*outputRowBytes + 3*x] = 255;
				outputPix[y*outputRowBytes + 3*x + 1] = 255;
				outputPix[y*outputRowBytes + 3*x + 2] = 255;
			}
		}
	}
	
	return output;
}

NSBitmapImageRep* normalize(NSBitmapImageRep *input, const int width, const int height)
{
	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*3 bitsPerPixel:24];
	unsigned int totalR = 0, totalG = 0, totalB = 0;
	
	const NSInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];
	
	unsigned char weight[9] = {
		1, 2, 1,
		2, 4, 2,
		1, 2, 1
	};
	
	for (int y = 1; y < height-1; y++)
	{
		for (int x = 1; x < width-1; x++)
		{
			totalR = 0;
			totalG = 0;
			totalB = 0;
			
			for (int dy = -1; dy <= 1; dy++) {
				for (int dx = -1; dx <= 1; dx++) {
					totalR += inputPix[(y+dy) * inputRowBytes + 3*(x+dx)] * weight[dx+1+3*(dy+1)];
					totalG += inputPix[(y+dy) * inputRowBytes + 3*(x+dx) + 1] * weight[dx+1+3*(dy+1)];
					totalB += inputPix[(y+dy) * inputRowBytes + 3*(x+dx) + 2] * weight[dx+1+3*(dy+1)];
				}
			}
			
			outputPix[y * outputRowBytes + 3*x] = (unsigned char)(totalR / 16);
			outputPix[y * outputRowBytes + 3*x + 1] = (unsigned char)(totalG / 16);
			outputPix[y * outputRowBytes + 3*x + 2] = (unsigned char)(totalB / 16);
		}
	}
	
	return output;
}

NSBitmapImageRep* findLine(NSBitmapImageRep *input, const int width, const int height)
{
	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*3 bitsPerPixel:24];
	
	const NSUInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSUInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];
	
	unsigned char r = 0, g = 0, b = 0;
	unsigned char prevR = 0, prevG = 0, prevB = 0;
	unsigned char dif = 0, prevdif = 0;
	
	for (int y = 1; y < height; y++)
	{
		for (int x = 1; x < width; x++)
		{
			r =inputPix[y*inputRowBytes + 3*x];
			g =inputPix[y*inputRowBytes + 3*x + 1];
			b =inputPix[y*inputRowBytes + 3*x + 2];
			
			dif = (abs(r - prevR)
				   + abs(g - prevG)
				   + abs(b - prevB))/3;
			
			if (prevdif - dif > EPS) {
				outputPix[y*outputRowBytes + 3*x] = 255;
				outputPix[y*outputRowBytes + 3*x + 1] = 255;
				outputPix[y*outputRowBytes + 3*x + 2] = 255;
			}
			
			prevR = r;
			prevG = g;
			prevB = b;
			prevdif = dif;
		}
	}
	
	for (int x = 1; x < width; x++)
	{
		for (int y = 1; y < height; y++)
		{
			r =inputPix[y*inputRowBytes + 3*x];
			g =inputPix[y*inputRowBytes + 3*x + 1];
			b =inputPix[y*inputRowBytes + 3*x + 2];
			
			dif = (abs(r - prevR)
				   + abs(g - prevG)
				   + abs(b - prevB))/3;
			
			if (prevdif - dif > EPS) {
				outputPix[y*outputRowBytes + 3*x] = 255;
				outputPix[y*outputRowBytes + 3*x + 1] = 255;
				outputPix[y*outputRowBytes + 3*x + 2] = 255;
			}
			
			prevR = r;
			prevG = g;
			prevB = b;
			prevdif = dif;
		}
	}
	
	return output;
}

NSBitmapImageRep* noizeCancel(NSBitmapImageRep *input, const int width, const int height)
{
	const int R = 1;
	
	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*3 bitsPerPixel:24];
	
	const NSUInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSUInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];
	
	int cx, cy, count = 0;
	
	for (cx = R; cx < width - R; cx++)
	{
		for (cy = R; cy < height - R; cy++)
		{
			
			outputPix[cy*outputRowBytes + 3*cx] = inputPix[cy*outputRowBytes + 3*cx];
			outputPix[cy*outputRowBytes + 3*cx + 1] = inputPix[cy*inputRowBytes + 3*cx + 1];
			outputPix[cy*outputRowBytes + 3*cx + 2] = inputPix[cy*inputRowBytes + 3*cx + 2];

			if (inputPix[cy*inputRowBytes + 3*cx] == 0)
			{
				continue;
			}

			count = 0;
			for (int x = cx-R; x <= cx+R; x++)
			{
				for (int y = cy-R; y <= cy+R; y++)
				{
					if (inputPix[y*inputRowBytes + 3*x] == 255)
					{
						count++;
					}
				}
			}
			
			if (count < 2*R+1)
			{
				outputPix[cy*outputRowBytes + 3*cx] = 0;
				outputPix[cy*outputRowBytes + 3*cx + 1] = 0;
				outputPix[cy*outputRowBytes + 3*cx + 2] = 0;
			}
		}
	};
	
	return output;
}

NSBitmapImageRep* thiness(NSBitmapImageRep *input, const int width, const int height)
{
	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*3 bitsPerPixel:24];
	
	const NSUInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSUInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];
	
	unsigned char r = 0, g = 0, b = 0;
	unsigned char prevR = 0, prevG = 0, prevB = 0;
	unsigned char dif = 0;
	
	for (int y = 1; y < height; y++)
	{
		for (int x = 1; x < width; x++)
		{
			r =inputPix[y*inputRowBytes + 3*x];
			g =inputPix[y*inputRowBytes + 3*x + 1];
			b =inputPix[y*inputRowBytes + 3*x + 2];
			
			dif = (r - prevR
				   + g - prevG
				   + b - prevB)/3;
			
			if (dif > EPS) {
				outputPix[y*outputRowBytes + 3*x] = 255;
				outputPix[y*outputRowBytes + 3*x + 1] = 255;
				outputPix[y*outputRowBytes + 3*x + 2] = 255;
			}
			
			prevR = r;
			prevG = g;
			prevB = b;
		}
	}
	
	for (int x = 1; x < width; x++)
	{
		for (int y = 1; y < height; y++)
		{
			r =inputPix[y*inputRowBytes + 3*x];
			g =inputPix[y*inputRowBytes + 3*x + 1];
			b =inputPix[y*inputRowBytes + 3*x + 2];
			
			dif = (r - prevR
				   + g - prevG
				   + b - prevB)/3;
			
			if (dif > EPS) {
				outputPix[y*outputRowBytes + 3*x] = 255;
				outputPix[y*outputRowBytes + 3*x + 1] = 255;
				outputPix[y*outputRowBytes + 3*x + 2] = 255;
			}
			
			prevR = r;
			prevG = g;
			prevB = b;
		}
	}
	
	return output;
}

Line* findEdge(NSBitmapImageRep *input, const int width, const int height)
{
	const NSUInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const double THETA_UNIT = M_PI / THETA_MAX;
	const int R_MAX = sqrt(width*width + height*height);
	const int R_MIN = 50;
	
	double *sn = malloc(sizeof(double) * THETA_MAX);
	double *cs = malloc(sizeof(double) * THETA_MAX);
	Line *lines = malloc(sizeof(Line) * LINE_MAX);
	
		//テーブルの用意
	for (int t = 0; t < THETA_MAX; t++)
	{
		sn[t] = sin(THETA_UNIT * t);
		cs[t] = cos(THETA_UNIT * t);
	}
	
		//走査
	int *counter = calloc(THETA_MAX*R_MAX*2, sizeof(int));
	int r;
	for (int y = 0; y < height; y++)
	{
		for (int x = 0; x < width; x++)
		{
			if (inputPix[y*inputRowBytes + 3*x] != 255)
			{
				continue;
			}
			
			for (int t = 0; t < THETA_MAX; t++)
			{
				r = cs[t]*x + sn[t]*y;
				counter[t*R_MAX*2 + r+R_MAX]++;
			}
		}
	}
	
		//集計
	int maxT = 0;
	int maxR = 0;
	int max = 0;
	int hitCount = 0;
	
	while (true)
	{
		max = 0;
		
		for (int t = 0; t < THETA_MAX; t++)
		{
			for (int r = -R_MAX; r < R_MAX; r++)
			{
				if (-R_MIN  < r && r < R_MIN) continue;
				
				if (counter[t*R_MAX*2 + r+R_MAX] > max)
				{
					maxT = t;
					maxR = r;
					max = counter[t*R_MAX*2 + r+R_MAX];
				}
			}
		}
		
		if (hitCount > LINE_MAX)
		{
			break;
		}
		lines[hitCount].t = maxT;
		lines[hitCount].r = maxR;
		hitCount++;
		
			//直線を引く
		if (maxT != 0)
		{
			int y;
			for (int x = 0; x < width; x++)
			{
				y = (maxR-cs[maxT]*x)/sn[maxT];
				if (y < 0 || y >= height) continue;
			}
		}

		if (maxT != THETA_MAX / 2)
		{
			int x;
			for (int y = 0; y < height; y++)
			{
				x = (maxR-sn[maxT]*y)/cs[maxT];
				if (x < 0 || x >= width) continue;
			}
		}
		
			//近傍の直線を消す
		for (int dr = -200; dr <= 200; dr++)
		{
			for (int dt = -50; dt <= 50; dt++)
			{
				if (maxT+dt < 0 || maxT+dt >= THETA_MAX) continue;
				if (maxR+dr < -R_MAX || maxR+dr >= R_MAX) continue;
				counter[(maxT+dt)*R_MAX*2 + (maxR+dr)+R_MAX] = 0;
			}
		}
	}
	
	free(sn);
	free(cs);
	free(counter);
	
	return lines;
}

Line *selectEdge(Line *lines, NSBitmapImageRep *input, const int width, const int height)
{
	const NSUInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];

	const double THETA_UNIT = M_PI / THETA_MAX;
	
	double *sn = malloc(sizeof(double) * THETA_MAX);
	double *cs = malloc(sizeof(double) * THETA_MAX);
	
		//テーブルの用意
	for (int t = 0; t < THETA_MAX; t++)
	{
		sn[t] = sin(THETA_UNIT * t);
		cs[t] = cos(THETA_UNIT * t);
	}

	Line *edges = malloc(sizeof(Line) * EDGE_MAX);
	
	unsigned int sum, squareSum, count;
	int px, py;
	int r, t;
	int d;
	for (int i = 0; i < LINE_MAX; i++)
	{
		sum = 0;
		squareSum = 0;
		count = 0;
		px = -1; py = -1;
		r = lines[i].r;
		t = lines[i].t;
		
		for (int x = 0; x < width; x++) {
			for (int y = 0; y < height; y++) {
				if (inputPix[y*inputRowBytes + 3*x] != 255)
				{
					continue;
				}

				if ((int)(cs[t]*x + sn[t]*y) == r)
				{
					if (px == -1)
					{
						px = x;
						py = y;
						continue;
					}
					
					d = sqrt(pow(x-px, 2) + pow(y-py, 2));
					squareSum += d*d;
					sum += d;
					count++;
					px = x;
					py = y;
				}
			}
		}
		lines[i].v = (squareSum/count - pow(sum/count, 2))/count/count;
	}

	int minV, minJ;
	for (int i = 0; i < EDGE_MAX; i++)
	{
		minV = 99999;
		minJ = 0;
		for (int j = 0; j < LINE_MAX; j++)
		{
			if (lines[j].v < minV)
			{
				minV = lines[j].v;
				minJ = j;
			}
		}
		
		edges[i].r = lines[minJ].r;
		edges[i].t = lines[minJ].t;
		edges[i].v = lines[minJ].v;
		lines[minJ].v = 99999;
	}

	free(sn);
	free(cs);
	
	return edges;
}

NSBitmapImageRep *drawEdge(Line *lines, NSBitmapImageRep *input, const int width, const int height)
{
	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width*3 bitsPerPixel:24];
	
	const NSUInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSUInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];
	
	const double THETA_UNIT = M_PI / THETA_MAX;
	
	double *sn = malloc(sizeof(double) * THETA_MAX);
	double *cs = malloc(sizeof(double) * THETA_MAX);
	
		//テーブルの用意
	for (int t = 0; t < THETA_MAX; t++)
	{
		sn[t] = sin(THETA_UNIT * t);
		cs[t] = cos(THETA_UNIT * t);
	}
	
		//走査
	for (int y = 0; y < height; y++)
	{
		for (int x = 0; x < width; x++)
		{
			outputPix[y*outputRowBytes + 3*x] = inputPix[y*inputRowBytes + 3*x];
			outputPix[y*outputRowBytes + 3*x + 1] = inputPix[y*inputRowBytes + 3*x + 1];
			outputPix[y*outputRowBytes + 3*x + 2] = inputPix[y*inputRowBytes + 3*x + 2];
		}
	}
	
	Line edge;
	int t;
	int r;
	for (int i = 0; i < EDGE_MAX; i++)
	{
		edge = lines[i];
		t = edge.t;
		r = edge.r;

		if (t != 0)
		{
			int y;
			for (int x = 0; x < width; x++)
			{
				y = (r-cs[t]*x)/sn[t];
				if (y < 0 || y >= height) continue;
				outputPix[y*outputRowBytes + 3*x] = 255;
			}
		}
		
		if (t != THETA_MAX / 2)
		{
			int x;
			for (int y = 0; y < height; y++)
			{
				x = (r-sn[t]*y)/cs[t];
				if (x < 0 || x >= width) continue;
				outputPix[y*outputRowBytes + 3*x] = 255;
			}
		}
	}
	
	free(sn);
	free(cs);
	
	return output;
}

Square findSquare(Line *edges, const int width, const int height)
{
	const double THETA_UNIT = M_PI / THETA_MAX;
	
	double *sn = malloc(sizeof(double) * THETA_MAX);
	double *cs = malloc(sizeof(double) * THETA_MAX);
	
		//テーブルの用意
	for (int t = 0; t < THETA_MAX; t++)
	{
		sn[t] = sin(THETA_UNIT * t);
		cs[t] = cos(THETA_UNIT * t);
	}
	
	int t1, t2;
	int r1, r2;
	int x, y;
	Pos corners[4];
	int count = 0;
	for (int i = 0; i < EDGE_MAX; i++)
	{
		for (int j = i+1; j < EDGE_MAX; j++)
		{
			t1 = edges[i].t; t2 = edges[j].t;
			r1 = edges[i].r; r2 = edges[j].r;
			
			if (t2 > t1) {
				x = (r1*sn[t2]-r2*sn[t1]) / sn[t2-t1];
				y = (r2*cs[t1]-r1*cs[t2]) / sn[t2-t1];
			} else {
				x = (r2*sn[t1]-r1*sn[t2]) / sn[t1-t2];
				y = (r1*cs[t2]-r2*cs[t1]) / sn[t1-t2];
			}
			
			if (x < 0 || x > width) continue;
			if (y < 0 || y > height) continue;
			
			if (count >= 4)
			{
				printf("pattern recognision error.");
				return (Square){(Pos){-1, -1}};
			}
			
			corners[count] = (Pos){x, y};
			count++;
		}
	}

	free(sn);
	free(cs);
	
	if (count != 4)
	{
		printf("pattern recognision error.");
		return (Square){(Pos){-1, -1}};
	}

		//p1: 原点からもっとも近い点
		//p2: p1よりx軸方向のの距離が大きい点
		//p3: 原点からもっとも遠い点
		//p4: p1よりx軸方向の距離が小さい点
	Square square;
	int l, maxL, maxI, minL, minI;
	maxL = 0;
	maxI = -1;
	minL = sqrt(width*width + height*height);
	minI = -1;
	for (int i = 0; i < 4; i++)
	{
		l = sqrt(pow(corners[i].x, 2)+pow(corners[i].y, 2));
		if (l > maxL)
		{
			maxL = l;
			maxI = i;
		}

		if (l < minL)
		{
			minL = l;
			minI = i;
		}
	}
	
	square.p1 = corners[minI];
	square.p3 = corners[maxI];

	square.p2.x = width;
	for (int i = 0; i < 4; i++)
	{
		if (i == maxI || i == minI) continue;
		
		if (corners[i].x < square.p4.x)
		{
			square.p2 = square.p4;
			square.p4 = corners[i];
		}
		else
		{
			square.p2 = corners[i];
		}
	}
	
	return square;
}

NSBitmapImageRep *clipping(Square square, NSBitmapImageRep *input, const int width, const int height)
{
	OUTPUT_WIDTH = sqrt(pow(square.p1.x-square.p2.x, 2) + pow(square.p1.y-square.p2.y, 2));
	OUTPUT_HEIGHT = sqrt(pow(square.p1.x-square.p4.x, 2) + pow(square.p1.y-square.p4.y, 2));

	NSBitmapImageRep *output = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
																	   pixelsWide:OUTPUT_WIDTH
																	   pixelsHigh:OUTPUT_HEIGHT
																	bitsPerSample:8
																  samplesPerPixel:3
																		 hasAlpha:NO
																		 isPlanar:NO
																   colorSpaceName:NSDeviceRGBColorSpace
																	  bytesPerRow:OUTPUT_WIDTH*3
																	 bitsPerPixel:24];
	
	const NSUInteger inputRowBytes = [input bytesPerRow];
	unsigned char *inputPix = [input bitmapData];
	
	const NSUInteger outputRowBytes = [output bytesPerRow];
	unsigned char *outputPix = [output bitmapData];

	const double sn = 1.0 * (square.p2.y-square.p1.y) / OUTPUT_WIDTH;
	const double cs = 1.0 * (square.p2.x-square.p1.x) / OUTPUT_WIDTH;
	const int mx = square.p1.x;
	const int my = square.p1.y;
	int x, y;
	
	for (int x2 = 0; x2 < OUTPUT_WIDTH; x2++)
	{
		for (int y2 = 0; y2 < OUTPUT_HEIGHT; y2++)
		{
			x =  cs*x2 - sn*y2 + mx;
			y =  sn*x2 + cs*y2 + my;

			if (x < 0 || x >= width || y < 0 || y >= height)
			{
				outputPix[y2*outputRowBytes + 3*x2] = 0;
				outputPix[y2*outputRowBytes + 3*x2 + 1] = 0;
				outputPix[y2*outputRowBytes + 3*x2 + 2] = 0;
			}
			else
			{
				outputPix[y2*outputRowBytes + 3*x2] = inputPix[y*inputRowBytes + 3*x];
				
				outputPix[y2*outputRowBytes + 3*x2 + 1] = inputPix[y*inputRowBytes + 3*x + 1];

				outputPix[y2*outputRowBytes + 3*x2 + 2] = inputPix[y*inputRowBytes + 3*x + 2];
			}
		}
	}
	
	return output;
}

int main(void)
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	NSData *output;
	openPanel.allowedFileTypes = @[@"png", @"jpg", @"jpeg"];
	
	if ([openPanel runModal] != NSOKButton)
	{
		NSLog(@"Canceled.");
		exit(0);
	}
	
	NSImage *inputImage = [[NSImage alloc] initWithContentsOfURL:openPanel.URL];
	
		//1. ファイルをimageRepデータに変換
	NSBitmapImageRep *imageRep = convertToImageRep(inputImage);
	const int width = (int)imageRep.pixelsWide;
	const int height = (int)imageRep.pixelsHigh;
	
		//2. 平滑化
	imageRep = normalize(imageRep, width, height);

		//3. 2値化
//	imageRep = monochrome(imageRep, width, height);
//	output = [imageRep representationUsingType:NSBMPFileType properties:nil];
//	save(output, [openPanel.URL.path stringByAppendingString:@"_out1.bmp"]);
	
		//4. 境界線検出
	imageRep = findLine(imageRep, width, height);
//	output = [imageRep representationUsingType:NSBMPFileType properties:nil];
//	save(output, [openPanel.URL.path stringByAppendingString:@"_out2.bmp"]);
	
		//5. 細線化
	imageRep = thiness(imageRep, width, height);
//	output = [imageRep representationUsingType:NSBMPFileType properties:nil];
//	save(output, [openPanel.URL.path stringByAppendingString:@"_out3.bmp"]);
	
		//6. ノイズキャンセル
	imageRep = noizeCancel(imageRep, width, height);
//	output = [imageRep representationUsingType:NSBMPFileType properties:nil];
//	save(output, [openPanel.URL.path stringByAppendingString:@"_out4.bmp"]);

		//7. 輪郭検出
	Line *edges = findEdge(imageRep, width, height);
	edges = selectEdge(edges, imageRep, width, height);
	imageRep = drawEdge(edges, imageRep, width, height);
//	output = [imageRep representationUsingType:NSBMPFileType properties:nil];
//	save(output, [openPanel.URL.path stringByAppendingString:@"_out5.bmp"]);
	
		//8. 頂点検出
	Square square = findSquare(edges, width, height);
	if (!square.p1.x == -1) {
		printf("rectangle recognision is failed.");
		exit(EXIT_FAILURE);
	}
	
		//9. 変形
	imageRep = clipping(square, convertToImageRep(inputImage), width, height);
	output = [imageRep representationUsingType:NSBMPFileType properties:nil];
	save(output, [openPanel.URL.path stringByAppendingString:@"_out6.bmp"]);

		//10. フィルタかけまくる
	imageRep = normalize(imageRep, width, height);
//	imageRep = monochrome(imageRep, OUTPUT_WIDTH, OUTPUT_HEIGHT);
	imageRep = thiness(imageRep, width, height);
	output = [imageRep representationUsingType:NSBMPFileType properties:nil];
	save(output, [openPanel.URL.path stringByAppendingString:@"_out7.bmp"]);
	
	return 0;
}

