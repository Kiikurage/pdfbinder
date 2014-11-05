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
#define LINE_MAX 8
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

typedef struct {
	unsigned char *data;
	unsigned int width;
	unsigned int height;
} Image;

#define pixelR(I, X, Y) ((I).data[(Y)*(I).width*3 + 3*(X)])
#define pixelG(I, X, Y) ((I).data[(Y)*(I).width*3 + 3*(X) + 1])
#define pixelB(I, X, Y) ((I).data[(Y)*(I).width*3 + 3*(X) + 2])

int OUTPUT_WIDTH;
int OUTPUT_HEIGHT;

void saveImage(Image image, NSString *path)
{
	NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
																		 pixelsWide:image.width
																		 pixelsHigh:image.height
																	  bitsPerSample:8
																	samplesPerPixel:3
																		   hasAlpha:NO
																		   isPlanar:NO
																	 colorSpaceName:NSDeviceRGBColorSpace
																		bytesPerRow:image.width*3
																	   bitsPerPixel:24];
	unsigned char *imagePix = [imageRep bitmapData];
	
	memcpy(imagePix, image.data, image.width*image.height*3);

	NSData *data = [imageRep representationUsingType:NSJPEGFileType properties:nil];
	[data writeToFile:path atomically:NO];
}

Image initImage(unsigned int width, unsigned int height)
{
	Image image;
	image.width = width;
	image.height = height;
	image.data = calloc(width * height * 3, sizeof(unsigned char));
	
	return image;
}

Image copyImage(Image src)
{
	Image image;
	image.data = malloc(sizeof(unsigned char) * src.width * src.height*3);
	memcpy(image.data, src.data, src.width*src.height*3);
	
	return image;
}

void deleteImage(Image image)
{
	free(image.data);
}

Image convertToColorImage(NSImage *nsimage)
{
	NSData *tiffData = [nsimage TIFFRepresentation];
	NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:tiffData];

	Image image;
	image.width = (unsigned int)imageRep.pixelsWide;
	image.height = (unsigned int)imageRep.pixelsHigh;
	image.data = imageRep.bitmapData;

	return image;
}

Image greyscale(Image input)
{
	Image output = initImage(input.width, input.height);

	for (int y = 1; y < output.height-1; y++)
	{
		for (int x = 1; x < output.width-1; x++)
		{
			pixelR(output, x, y) =
			pixelG(output, x, y) =
			pixelB(output, x, y) =
			(pixelR(input, x, y)*2 + pixelG(input, x, y)*4 + pixelB(input, x, y)) / 7;
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

Image monochrome(Image input)
{
	Image output = initImage(input.width, input.height);
	
	int arrBrightness[64];//幅4で64段階
	for (int i = 0; i < 64; i++) arrBrightness[i] = 0;
	
	for (int y = 0; y < input.height; y++) {
		for (int x = 0; x < input.width; x++) {
			arrBrightness[(pixelR(input, x, y)*2
						   + pixelG(input, x, y)*4
						   + pixelB(input, x, y))
						  /7/4]++;
		}
	}
	int threshold = detectThreshold(arrBrightness, 64);
	
	for (int y = 1; y < input.height; y++) {
		for (int x = 1; x < input.width; x++) {
			if ((pixelR(input, x, y)*2
				 + pixelG(input, x, y)*4
				 + pixelB(input, x, y))/7 < threshold*4) {
				pixelR(output, x, y) = 0;
				pixelG(output, x, y) = 0;
				pixelB(output, x, y) = 0;
			} else {
				pixelR(output, x, y) = 255;
				pixelG(output, x, y) = 255;
				pixelB(output, x, y) = 255;
			}
		}
	}
	
	return output;
}

Image normalize(Image input)
{
	Image output = initImage(input.width, input.height);
	unsigned int totalR = 0, totalG = 0, totalB = 0;
	
	unsigned char weight[9] = {
		1, 2, 1,
		2, 4, 2,
		1, 2, 1
	};
	
	for (int y = 1; y < input.height-1; y++)
	{
		for (int x = 1; x < input.width-1; x++)
		{
			totalR = 0;
			totalG = 0;
			totalB = 0;
			
			for (int dy = -1; dy <= 1; dy++) {
				for (int dx = -1; dx <= 1; dx++) {
					totalR += pixelR(input, x+dx, y+dy) * weight[(dx+1)+3*(dy+1)];
					totalG += pixelG(input, x+dx, y+dy) * weight[(dx+1)+3*(dy+1)];
					totalB += pixelB(input, x+dx, y+dy) * weight[(dx+1)+3*(dy+1)];
				}
			}
			
			pixelR(output, x, y) = totalR/16;
			pixelG(output, x, y) = totalG/16;
			pixelB(output, x, y) = totalB/16;
		}
	}
	
	return output;
}

Image findLine(Image input)
{
	Image output = initImage(input.width, input.height);
	
	unsigned char r = 0, g = 0, b = 0;
	unsigned char prevR = 0, prevG = 0, prevB = 0;
	unsigned char dif = 0, prevdif = 0;
	
	for (int y = 1; y < input.height; y++)
	{
		for (int x = 1; x < input.width; x++)
		{
			r = pixelR(input, x, y);
			g = pixelG(input, x, y);
			b = pixelB(input, x, y);
			
			dif = (abs(r - prevR)
				   + abs(g - prevG)
				   + abs(b - prevB))/3;
			
			if (prevdif - dif > EPS) {
				pixelR(output, x, y) = 255;
				pixelG(output, x, y) = 255;
				pixelB(output, x, y) = 255;
			}
			
			prevR = r;
			prevG = g;
			prevB = b;
			prevdif = dif;
		}
	}
	
	for (int x = 1; x < input.width; x++)
	{
		for (int y = 1; y < input.height; y++)
		{
			r = pixelR(input, x, y);
			g = pixelG(input, x, y);
			b = pixelB(input, x, y);
			
			dif = (abs(r - prevR)
				   + abs(g - prevG)
				   + abs(b - prevB))/3;
			
			if (prevdif - dif > EPS) {
				pixelR(output, x, y) = 255;
				pixelG(output, x, y) = 255;
				pixelB(output, x, y) = 255;
			}
			
			prevR = r;
			prevG = g;
			prevB = b;
			prevdif = dif;
		}
	}
	
	return output;
}

Image noizeCancel(Image input)
{
	const int R = 1;

	Image output = copyImage(input);
	int cx, cy, count = 0;
	
	for (cx = R; cx < input.width - R; cx++)
	{
		for (cy = R; cy < input.height - R; cy++)
		{
			if (pixelR(input, cx, cy) == 0)
			{
				continue;
			}
			
			count = 0;
			for (int x = cx-R; x <= cx+R; x++)
			{
				for (int y = cy-R; y <= cy+R; y++)
				{
					if (pixelR(input, x, y) == 255)
					{
						count++;
					}
				}
			}
			
			if (count < 2*R+1)
			{
				pixelR(output, cx, cy) = 0;
				pixelG(output, cx, cy) = 0;
				pixelB(output, cx, cy) = 0;
			}
		}
	};
	
	return output;
}

Image thiness(Image input)
{
	Image output = initImage(input.width, input.height);
	
	unsigned char pix = 0;
	unsigned char prev = 0;
	unsigned char dif = 0;
	
	for (int y = 1; y < input.height; y++)
	{
		for (int x = 1; x < input.width; x++)
		{
			pix = pixelR(input, x, y);
			dif = pix - prev;

			if (dif > EPS) {
				pixelR(output, x, y) = 255;
				pixelG(output, x, y) = 255;
				pixelB(output, x, y) = 255;
			}
			
			prev = pix;
		}
	}
	
	for (int x = 1; x < input.width; x++)
	{
		for (int y = 1; y < input.height; y++)
		{
			pix = pixelR(input, x, y);
			dif = pix - prev;
			
			if (dif > EPS) {
				pixelR(output, x, y) = 255;
				pixelG(output, x, y) = 255;
				pixelB(output, x, y) = 255;
			}
			
			prev = pix;
		}
	}

	
	return output;
}

Line* findEdge(Image input)
{
	const double THETA_UNIT = M_PI / THETA_MAX;
	const int R_MAX = sqrt(input.width*input.width + input.height*input.height);
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
	for (int y = 0; y < input.height; y++)
	{
		for (int x = 0; x < input.width; x++)
		{
			if (pixelR(input, x, y) != 255)
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
	
	const int REMOVE_RANGE_R = MIN(input.width, input.height) / 2;

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
			for (int x = 0; x < input.width; x++)
			{
				y = (maxR-cs[maxT]*x)/sn[maxT];
				if (y < 0 || y >= input.height) continue;
			}
		}
		
		if (maxT != THETA_MAX / 2)
		{
			int x;
			for (int y = 0; y < input.height; y++)
			{
				x = (maxR-sn[maxT]*y)/cs[maxT];
				if (x < 0 || x >= input.width) continue;
			}
		}
		
		//近傍の直線を消す
		int offsetT, reverseR;
		for (int dr = -REMOVE_RANGE_R; dr <= REMOVE_RANGE_R; dr++)
		{
			for (int dt = -100; dt <= 100; dt++)
			{
				if (maxT+dt < 0)
				{
					offsetT = THETA_MAX;
					reverseR = -1;
				}
				else if (maxT+dt >= THETA_MAX)
				{
					offsetT = -THETA_MAX;
					reverseR = -1;
				}
				else
				{
					offsetT = 0;
					reverseR = 1;
				}
				if (maxR+dr < -R_MAX || maxR+dr >= R_MAX) continue;
				counter[(maxT+dt+offsetT)*R_MAX*2 + reverseR*(maxR+dr)+R_MAX] = 0;
			}
		}
	}
	
	free(sn);
	free(cs);
	free(counter);
	
	return lines;
}

Image drawLine(Line *lines, Image input)
{
	Image output = copyImage(input);
	
	const double THETA_UNIT = M_PI / THETA_MAX;
	
	double *sn = malloc(sizeof(double) * THETA_MAX);
	double *cs = malloc(sizeof(double) * THETA_MAX);
	
	//テーブルの用意
	for (int t = 0; t < THETA_MAX; t++)
	{
		sn[t] = sin(THETA_UNIT * t);
		cs[t] = cos(THETA_UNIT * t);
	}
	
	Line line;
	int t;
	int r;
	for (int i = 0; i < LINE_MAX; i++)
	{
		line = lines[i];
		t = line.t;
		r = line.r;
		
		if (t != 0)
		{
			int y;
			for (int x = 0; x < output.width; x++)
			{
				y = (r-cs[t]*x)/sn[t];
				if (y < 0 || y >= output.height) continue;
				pixelB(output, x, y) = 255;
			}
		}
		
		if (t != THETA_MAX / 2)
		{
			int x;
			for (int y = 0; y < output.height; y++)
			{
				x = (r-sn[t]*y)/cs[t];
				if (x < 0 || x >= output.width) continue;
				pixelB(output, x, y) = 255;
			}
		}
	}
	
	free(sn);
	free(cs);
	
	return output;
}

Line *selectEdge(Line *lines, Image input, int countWeight)
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
		
		for (int x = 0; x < input.width; x++) {
			for (int y = 0; y < input.height; y++) {
				if (pixelR(input, x, y) != 255)
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
		lines[i].v = (int)((squareSum/count - pow(sum/count, 2))/pow(count, countWeight));
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

Image drawEdge(Line *lines, Image input)
{
	Image output = copyImage(input);
	
	const double THETA_UNIT = M_PI / THETA_MAX;
	
	double *sn = malloc(sizeof(double) * THETA_MAX);
	double *cs = malloc(sizeof(double) * THETA_MAX);
	
	//テーブルの用意
	for (int t = 0; t < THETA_MAX; t++)
	{
		sn[t] = sin(THETA_UNIT * t);
		cs[t] = cos(THETA_UNIT * t);
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
			for (int x = 0; x < output.width; x++)
			{
				y = (r-cs[t]*x)/sn[t];
				if (y < 0 || y >= output.height) continue;
				pixelR(output, x, y) = 255;
				pixelG(output, x, y) = 0;
				pixelB(output, x, y) = 0;
			}
		}
		
		if (t != THETA_MAX / 2)
		{
			int x;
			for (int y = 0; y < output.height; y++)
			{
				x = (r-sn[t]*y)/cs[t];
				if (x < 0 || x >= output.width) continue;
				pixelR(output, x, y) = 255;
				pixelG(output, x, y) = 0;
				pixelB(output, x, y) = 0;
			}
		}
	}
	
	free(sn);
	free(cs);
	
	return output;
}

Square findSquare(Line *edges, Image input)
{
	const int width = input.width;
	const int height = input.height;
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
				printf("pattern recognision error.\n");
				return (Square){-1, -1, -1, -1, -1, -1, -1, -1};
			}
			
			corners[count] = (Pos){x, y};
			count++;
		}
	}
	
	free(sn);
	free(cs);
	
	if (count != 4)
	{
		printf("pattern recognision error.\n");
		return (Square){-1, -1, -1, -1, -1, -1, -1, -1};
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
	
	square.p4.x = width;
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

Image drawSquare(Square square, Image input)
{
	Image output = copyImage(input);
	
	Pos p1 = square.p1;
	Pos p2 = square.p2;
	Pos p3 = square.p3;
	Pos p4 = square.p4;
	
	for (int dx = -10; dx <= 10; dx++)
	{
		for (int dy = -10; dy <= 10; dy++)
		{
			if (p1.x+dx > 0 && p1.x+dx < input.width && p1.y+dy > 0 && p1.y+dy < input.height) {
				pixelR(output, p1.x+dx, p1.y+dy) = 0;
				pixelG(output, p1.x+dx, p1.y+dy) = 255;
				pixelB(output, p1.x+dx, p1.y+dy) = 0;
			}
			
			if (p2.x+dx > 0 && p2.x+dx < input.width && p2.y+dy > 0 && p2.y+dy < input.height) {
				pixelR(output, p2.x+dx, p2.y+dy) = 255;
				pixelG(output, p2.x+dx, p2.y+dy) = 0;
				pixelB(output, p2.x+dx, p2.y+dy) = 255;
			}
			
			if (p3.x+dx > 0 && p3.x+dx < input.width && p3.y+dy > 0 && p3.y+dy < input.height) {
				pixelR(output, p3.x+dx, p3.y+dy) = 255;
				pixelG(output, p3.x+dx, p3.y+dy) = 128;
				pixelB(output, p3.x+dx, p3.y+dy) = 0;
			}
			
			if (p4.x+dx > 0 && p4.x+dx < input.width && p4.y+dy > 0 && p4.y+dy < input.height) {
				pixelR(output, p4.x+dx, p4.y+dy) = 0;
				pixelG(output, p4.x+dx, p4.y+dy) = 255;
				pixelB(output, p4.x+dx, p4.y+dy) = 255;
			}
			
		}
	}
	
	return output;
}

Image clipping(Square square, Image input)
{
	OUTPUT_WIDTH = sqrt(pow(square.p1.x-square.p2.x, 2) + pow(square.p1.y-square.p2.y, 2));
	OUTPUT_HEIGHT = sqrt(pow(square.p1.x-square.p4.x, 2) + pow(square.p1.y-square.p4.y, 2));
	
	Image output = initImage(OUTPUT_WIDTH, OUTPUT_HEIGHT);

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
			
			if (x < 0 || x >= input.width || y < 0 || y >= input.height)
			{
				pixelR(output, x2, y2) = 0;
				pixelG(output, x2, y2) = 0;
				pixelB(output, x2, y2) = 0;
			}
			else
			{
				pixelR(output, x2, y2) = pixelR(input, x, y);
				pixelG(output, x2, y2) = pixelG(input, x, y);
				pixelB(output, x2, y2) = pixelB(input, x, y);
			}
		}
	}
	
	return output;
}

int main(void)
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = @[@"png", @"jpg", @"jpeg"];
	
	if ([openPanel runModal] != NSModalResponseOK)
	{
		NSLog(@"Canceled.");
		exit(0);
	}
	
	NSImage *inputImage = [[NSImage alloc] initWithContentsOfURL:openPanel.URL];
	
	//1. ファイルをimageRepデータに変換
	Image image1 = convertToColorImage(inputImage);
	saveImage(image1, [openPanel.URL.path stringByAppendingString:@"_out1.jpg"]);
	
	//2. 平滑化
	Image image2 = monochrome(image1);
	saveImage(image2, [openPanel.URL.path stringByAppendingString:@"_out2.jpg"]);
	
	//3. 境界線検出
	Image image3 = findLine(image2);
	deleteImage(image2);
	saveImage(image3, [openPanel.URL.path stringByAppendingString:@"_out3.jpg"]);
	
	//4. ノイズキャンセル
	Image image4 = noizeCancel(image3);
	deleteImage(image3);
	saveImage(image4, [openPanel.URL.path stringByAppendingString:@"_out4.jpg"]);
	
	//5. 輪郭検出
	Line *lines = findEdge(image4);
	Image image5 = drawLine(lines, image4);
	saveImage(image5, [openPanel.URL.path stringByAppendingString:@"_out5.jpg"]);
	deleteImage(image5);
	
	int countWeight = 3;
	Line *edges;
	Square square;
	Image image6;
	while (true)
	{
		if (countWeight == 0)
		{
			exit(EXIT_FAILURE);
		}
		
		//6. 領域選択
		edges = selectEdge(lines, image4, countWeight);
		image6 = drawEdge(edges, image4);
		saveImage(image6, [openPanel.URL.path stringByAppendingString:@"_out6.jpg"]);
		deleteImage(image6);
		
		//7. 頂点検出
		square = findSquare(edges, image4);
		
		if (square.p1.x != -1) break;
		countWeight--;
	}
	Image image7 = drawSquare(square, image4);
	saveImage(image7, [openPanel.URL.path stringByAppendingString:@"_out7.jpg"]);
	deleteImage(image4);
	deleteImage(image7);
	
	//9. 変形
	Image image8 = clipping(square, image1);
	saveImage(image8, [openPanel.URL.path stringByAppendingString:@"_out8.jpg"]);

	//10. フィルタかけまくる
//	Image image10 = monochrome(image9);
//	ColorImage image11 = normalize(image10);
//	saveColorImage(image11, [openPanel.URL.path stringByAppendingString:@"_out10.jpg"]);
//	deleteImage(image10);
//	deleteColorImage(image11);
	
	return 0;
}

