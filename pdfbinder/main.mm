//
//  main.cpp
//  pdfbinder
//
//  Created by KikuraYuichiro on 2014/11/03.
//  Copyright (c) 2014年 KikuraYuichiro. All rights reserved.
//

#include <Cocoa/Cocoa.h>
#include <stdlib.h>
#include <vector>
#include "./Image.h"
#include "./filter.h"

#define THETA_MAX 		2048				//角度の分解能
#define EDGE_MAX	 	30					//findEdgeで検出する境界線の数
#define EDGE_MARGIN		30					//findEdgeで走査を無視するマージンサイズ
#define MAX_PARALLEL_DT (THETA_MAX*0.30)	//2つの直線を平行とみなす許容誤差角度
#define MAX_VERTICAL_DT (THETA_MAX*0.10)	//2つの直線を垂直とみなす許容誤差角度
#define REMOVE_RANGE_T	(THETA_MAX*0.03)	//削除する近傍角度

typedef struct {
	Line l1;
	Line l2;
	int t;
} LinePair;

typedef std::vector<Line> LineList;
typedef std::vector<LinePair> LinePairList;

double *sn;
double *cs;

void saveImage(Image *image, NSString *path)
{
	NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
																		 pixelsWide:image->width
																		 pixelsHigh:image->height
																	  bitsPerSample:8
																	samplesPerPixel:3
																		   hasAlpha:NO
																		   isPlanar:NO
																	 colorSpaceName:NSDeviceRGBColorSpace
																		bytesPerRow:image->width*3
																	   bitsPerPixel:24];
	unsigned char *imagePix = [imageRep bitmapData];
	
	memcpy(imagePix, image->data, image->width*image->height*3);

	NSData *data = [imageRep representationUsingType:NSJPEGFileType properties:nil];
	[data writeToFile:path atomically:NO];
}

Image* loadImage(NSString *path)
{
	NSImage *nsimage = [[NSImage alloc] initWithContentsOfFile:path];
	NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:nsimage.TIFFRepresentation];

	Image *image = new Image((unsigned int)imageRep.pixelsWide, (unsigned int)imageRep.pixelsHigh);
	memcpy(image->data, imageRep.bitmapData, image->width*image->height*3);

	return image;
}

void setup()
{
	const double THETA_UNIT = M_PI / THETA_MAX;
	
	//テーブルの用意
	sn = (double *)malloc(sizeof(double) * THETA_MAX);
	cs = (double *)malloc(sizeof(double) * THETA_MAX);
	
	for (int t = 0; t < THETA_MAX; t++)
	{
		sn[t] = sin(THETA_UNIT * t);
		cs[t] = cos(THETA_UNIT * t);
	}
}

void cleanup()
{
	free(sn);
	free(cs);
}

LineList findLine(Image *input)
{
	const unsigned int width = input->width;
	const unsigned int height = input->height;
	const int R_MAX = sqrt(width*width + height*height);
	LineList lines;
	
	//走査
	int *counter = (int *)calloc(THETA_MAX*R_MAX*2, sizeof(int));
	int r;
	for (int y = EDGE_MARGIN; y < height-EDGE_MARGIN; y++)
	{
		for (int x = EDGE_MARGIN; x < width-EDGE_MARGIN; x++)
		{
			if (input->getR(x, y) != 255)
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
	int max = 0, maxT = 0, maxR = 0;
	int x0, y0, x1, y1, y_x0, y_x1;
	int hitCount = 0;
	
	const int REMOVE_RANGE_R = MIN(width, height) / 5;

	while (hitCount < EDGE_MAX)
	{
		max = 0;
		
		for (int t = 0; t < THETA_MAX; t++)
		{
			for (int r = -R_MAX; r < R_MAX; r++)
			{
				if (counter[t*R_MAX*2 + r+R_MAX] > max)
				{
					maxT = t;
					maxR = r;
					max = counter[t*R_MAX*2 + r+R_MAX];
				}
			}
		}
		y_x0 = maxR/sn[maxT];
		x0 = y_x0 < 0 ? maxR/cs[maxT] : (y_x0 > height ? ((maxR-sn[maxT]*height)/cs[maxT]) : 0   );
		y0 = y_x0 < 0 ? 0             : (y_x0 > height ? height-1                          : y_x0);

		y_x1 = (maxR-cs[maxT]*width)/sn[maxT];
		x1 = y_x1 < 0 ? maxR/cs[maxT] : (y_x1 > height ? ((maxR-sn[maxT]*height)/cs[maxT]) : width-1);
		y1 = y_x1 < 0 ? 0             : (y_x1 > height ? height-1                          : y_x1   );

		lines.push_back((Line){
			maxT,
			maxR,
			(Pos){x0, y0},
			(Pos){x1, y1}
		});
		hitCount++;
		
		//近傍の直線を消す
		int offsetT, reverseR;
		for (int dr = -REMOVE_RANGE_R; dr <= REMOVE_RANGE_R; dr++)
		{
			for (int dt = -REMOVE_RANGE_T; dt <= REMOVE_RANGE_T; dt++)
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

	free(counter);
	return lines;
}

Image* drawLine(Image *input, const Line line, const Color lineColor)
{
	Pos p1 = line.p1;
	Pos p2 = line.p2;

	if (p1.x != p2.x)
	{
		int x1 = p1.x < p2.x ? p1.x : p2.x;
		int x2 = p1.x < p2.x ? p2.x : p1.x;
		int y;
		double a = 1.0*(p2.y-p1.y)/(p2.x-p1.x);
		for (int x = x1; x < x2; x++)
		{
			y = a*(x-p1.x)+p1.y;
			input->setR(x, y, lineColor.r);
			input->setG(x, y, lineColor.g);
			input->setB(x, y, lineColor.b);
		}
	}
	
	if (p1.y != p2.y)
	{
		int y1 = p1.y < p2.y ? p1.y : p2.y;
		int y2 = p1.y < p2.y ? p2.y : p1.y;
		int x;
		double a = 1.0*(p2.x-p1.x)/(p2.y-p1.y);
		for (int y = y1; y < y2; y++)
		{
			x = a*(y-p1.y)+p1.x;
			input->setR(x, y, lineColor.r);
			input->setG(x, y, lineColor.g);
			input->setB(x, y, lineColor.b);
		}
	}

	return input;
}

Image* drawLines(Image *input, const LineList lines, const Color lineColor)
{
	Line line;
	auto lineIterator = lines.begin();
	while(lineIterator != lines.end())
	{
		line = *lineIterator;
		drawLine(input, line, lineColor);
		
		lineIterator++;
	}
	
	return input;
}

LinePairList findParallelPair(Image *input, LineList lines)
{
	std::vector<LinePair> linePairList;
	auto lineIterator1 = lines.begin();
	
	while (lineIterator1 != lines.end())
	{
		Line l1 = *lineIterator1;
		auto lineIterator2 = lineIterator1+1;
		
		while (lineIterator2 != lines.end())
		{
			Line l2 = *lineIterator2;
			int dt = abs(l1.t - l2.t);
			
			if (dt > THETA_MAX/2) dt = THETA_MAX - dt;
			
			if (dt < MAX_PARALLEL_DT) linePairList.push_back((LinePair){l1, l2, l1.t});
			
			lineIterator2++;
		}
		
		lineIterator1++;
	}
	
	return linePairList;
}

LineList selectEdge(Image *input, LineList lines)
{
	//1. 平行な線の組を作る
	LinePairList linePairList = findParallelPair(input, lines);
	
	//2. 垂直に交差する組を探す
	typedef struct {
		LinePair p1;
		LinePair p2;
	} LinePairPair;
	
	auto pairIterator1 = linePairList.begin();
	
	LineList edges;
	while (pairIterator1 != linePairList.end())
	{
		auto pairIterator2 = pairIterator1+1;
		LinePair p1 = *pairIterator1;

		while (pairIterator2 != linePairList.end())
		{
			LinePair p2 = *pairIterator2;
			int dt = abs(THETA_MAX/2 - abs(p1.t - p2.t)); //2つのペアの直角(THETA_MAX/2)からのズレ
			
			if (dt < MAX_VERTICAL_DT)
			{
				edges.push_back(p1.l1);
				edges.push_back(p1.l2);
				edges.push_back(p2.l1);
				edges.push_back(p2.l2);
				return edges;
			}
			
			pairIterator2++;
		}

		pairIterator1++;
	}

	return edges;
}

Square findSquare(Image *input, LineList edges)
{
	const unsigned int width = input->width;
	const unsigned int height = input->height;
	
	int t1, t2, r1, r2;
	int x, y;
	Pos corners[4];
	Line edge1, edge2;
	int count = 0;
	auto lineIterator1 = edges.begin();
	
	while (lineIterator1 != edges.end())
	{
		edge1 = *lineIterator1;
		auto lineIterator2 = lineIterator1+1;
		
		while (lineIterator2 != edges.end())
		{
			edge2 = *lineIterator2;
			
			t1 = edge1.t; t2 = edge2.t;
			r1 = edge1.r; r2 = edge2.r;
			
			if (t2 > t1) {
				x = (r1*sn[t2]-r2*sn[t1]) / sn[t2-t1];
				y = (r2*cs[t1]-r1*cs[t2]) / sn[t2-t1];
			} else {
				x = (r2*sn[t1]-r1*sn[t2]) / sn[t1-t2];
				y = (r1*cs[t2]-r2*cs[t1]) / sn[t1-t2];
			}
			
			if (x < 0 || x > width || y < 0 || y > height)
			{
				lineIterator2++;
				continue;
			}
			
			if (count >= 4)
			{
				printf("pattern recognision error.\n");
				return (Square){-1, -1, -1, -1, -1, -1, -1, -1};
			}
			
			corners[count] = (Pos){x, y};
			count++;
			
			lineIterator2++;
		}
		
		lineIterator1++;
	}
	
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

Image* drawSquare(Image *input, Square square)
{
	Pos p1 = square.p1;
	Pos p2 = square.p2;
	Pos p3 = square.p3;
	Pos p4 = square.p4;
	
	const unsigned int width = input->width;
	const unsigned int height = input->height;
	
	for (int dx = -10; dx <= 10; dx++)
	{
		for (int dy = -10; dy <= 10; dy++)
		{
			if (p1.x+dx > 0 && p1.x+dx < width && p1.y+dy > 0 && p1.y+dy < height) {
				input->setR(p1.x+dx, p1.y+dy, 255);
			}
			
			if (p2.x+dx > 0 && p2.x+dx < width && p2.y+dy > 0 && p2.y+dy < height) {
				input->setR(p2.x+dx, p2.y+dy, 255);
			}

			if (p3.x+dx > 0 && p3.x+dx < width && p3.y+dy > 0 && p3.y+dy < height) {
				input->setR(p3.x+dx, p3.y+dy, 255);
			}

			if (p4.x+dx > 0 && p4.x+dx < width && p4.y+dy > 0 && p4.y+dy < height) {
				input->setR(p4.x+dx, p4.y+dy, 255);
			}
		}
	}
	
	return input;
}

Image* largeMeshClipping(Image *input, const Square square, const int radius)
{
	const int width = MAX(abs(square.p1.x-square.p3.x), abs(square.p2.x-square.p4.x))+2*radius;
	const int height = MAX(abs(square.p1.y-square.p3.y), abs(square.p2.y-square.p4.y))+2*radius;
	
	int x2_0 = MIN(square.p1.x, square.p4.x)-radius;
	int y2_0 = MIN(square.p1.y, square.p2.y)-radius;
	unsigned char *data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));

	int x, y;
	
	Pos edgePair[4][2] = {
		{square.p1, square.p2},
		{square.p2, square.p3},
		{square.p3, square.p4},
		{square.p4, square.p1}
	};
	
	for (int i = 0; i < 4; i++)
	{
		Pos p1 = edgePair[i][0];
		Pos p2 = edgePair[i][1];
		int a = p1.y - p2.y;
		int b = p2.x - p1.x;
		int c = p1.x*p2.y - p2.x*p1.y;
		int a2b2 = a*a+b*b;
		int r2 = radius*radius;
		
		for (int y2 = 0; y2 < height; y2++)
		{
			for (int x2 = 0; x2 < width; x2++)
			{
				x =  x2 + x2_0;
				y =  y2 + y2_0;
				
				if (x < 0 || x >= input->width || y < 0 || y >= input->height || input->getR(x, y) != 255)
				{
					continue;
				}

				if (pow(a*x+b*y+c, 2)/a2b2 < r2)
				{
					data[(y2*width+x2)*3] = 255;
				}
			}
		}
	}
	
	free(input->data);
	input->data = data;
	input->width = width;
	input->height = height;
	return input;
}

Image* clipping(Image *input, Square square)
{
	const int width = sqrt(pow(square.p1.x-square.p2.x, 2) + pow(square.p1.y-square.p2.y, 2));
	const int height = sqrt(pow(square.p1.x-square.p4.x, 2) + pow(square.p1.y-square.p4.y, 2));
	
	Image *output = new Image(width, height);

	const double sn = 1.0 * (square.p2.y-square.p1.y) / output->width;
	const double cs = 1.0 * (square.p2.x-square.p1.x) / output->width;
	const int mx = square.p1.x;
	const int my = square.p1.y;
	int x, y;
	
	for (int x2 = 0; x2 < output->width; x2++)
	{
		for (int y2 = 0; y2 < output->height; y2++)
		{
			x =  cs*x2 - sn*y2 + mx;
			y =  sn*x2 + cs*y2 + my;
			
			if (x < 0 || x >= input->width || y < 0 || y >= input->height)
			{
				output->set(x2, y2, 0);
			}
			else
			{
				output->setR(x2, y2, input->getR(x, y));
				output->setG(x2, y2, input->getG(x, y));
				output->setB(x2, y2, input->getB(x, y));
			}
		}
	}
	
	return output;
}

Image* specialClipping(Image *input, Square square)
{
	const int x1 = square.p1.x;
	const int y1 = square.p1.y;
	
	const int x2 = square.p2.x;
	const int y2 = square.p2.y;
	
	const int x3 = square.p3.x;
	const int y3 = square.p3.y;
	
	const int x4 = square.p4.x;
	const int y4 = square.p4.y;
	
	const int w12 = pow(x1-x2, 2) + pow(y1-y2, 2);
	const int w14 = pow(x1-x4, 2) + pow(y1-y4, 2);
	const int W = w12 > w14 ? 1414 : 1000;
	const int H = w12 > w14 ? 1000 : 1414;
	
	const double h33 =  1.0;
	const double h31 = h33*((x3-x4)*(y1-y2)-(y3-y4)*(x1-x2))/W/((y3-y4)*(x3-x2)-(x3-x4)*(y3-y2));
	const double h32 = h33*((x3-x2)*(y1-y4)-(y3-y2)*(x1-x4))/H/((y3-y2)*(x3-x4)-(x3-x2)*(y3-y4));
	
	const double h13 = h33*x1;
	const double h23 = h33*y1;

	const double h11 = 1.0*((h31*W+h33)*x2-h13)/W;
	const double h21 = 1.0*((h31*W+h33)*y2-h23)/W;
	const double h12 = 1.0*((h32*H+h33)*x4-h13)/H;
	const double h22 = 1.0*((h32*H+h33)*y4-h23)/H;

	Image *output = new Image(W, H);
	
	int x, y;
	
	for (int xOut = 0; xOut < W; xOut++)
	{
		for (int yOut = 0; yOut < H; yOut++)
		{
			x = (h11*xOut+h12*yOut+h13)/(h31*xOut+h32*yOut+h33);
			y = (h21*xOut+h22*yOut+h23)/(h31*xOut+h32*yOut+h33);
			
			if (x < 0 || x >= input->width || y < 0 || y >= input->height)
			{
				output->set(xOut, yOut, 0);
			}
			else
			{
				output->setR(xOut, yOut, input->getR(x, y));
				output->setG(xOut, yOut, input->getG(x, y));
				output->setB(xOut, yOut, input->getB(x, y));
			}
		}
	}
	
	return output;
}

int main(void)
{
	clock_t timestamp;
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = @[@"png", @"jpg", @"jpeg"];
	if ([openPanel runModal] != NSModalResponseOK)
	{
		NSLog(@"Canceled.");
		exit(0);
	}
	
	timestamp = clock();
	
	NSString *path = openPanel.URL.path;
	Image *input = loadImage(openPanel.URL.relativePath);
	Image *image = input->copy();
	
	setup();
	
	Filter::edge(image);
	Filter::noizeCancel(image, 10, 0.95);

	LineList lines = findLine(image);

	Image *lineImage = image->copy();
	drawLines(lineImage, lines, (Color){0, 255, 0});
	saveImage(lineImage, [path stringByAppendingString:@"2.jpg"]);
	delete lineImage;
	
	LineList edges = selectEdge(image, lines);

	Image *edgeImage = image->copy();
	drawLines(edgeImage, edges, (Color){0, 255, 0});
	saveImage(edgeImage, [path stringByAppendingString:@"3.jpg"]);
	delete edgeImage;
	
	Square square = findSquare(image, edges);
	if (square.p1.x == -1) {
		printf("Error\n");
		exit(EXIT_FAILURE);
	}
	
//	Image *squareImage = image->copy();
//	drawSquare(squareImage, square);
//	saveImage(squareImage, [path stringByAppendingString:@"3.jpg"]);
//	delete squareImage;

	Image *output;
 
	output = clipping(input, square);
	saveImage(output, [path stringByAppendingString:@"5_normal.jpg"]);
	delete output;
	
	output = specialClipping(input, square);
	saveImage(output, [path stringByAppendingString:@"5_result.jpg"]);
	delete output;

	cleanup();
	delete image;
	delete input;
	
	printf("finish time:%lf\n", 1.0*(clock()-timestamp)/CLOCKS_PER_SEC);
	
	return 0;
}

