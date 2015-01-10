//
//  filter.cpp
//  pdfbinder
//
//  Created by kikurage on 2014/11/08.
//  Copyright (c) 2014年 KikuraYuichiro. All rights reserved.
//

#include "filter.h"

namespace Filter {
	
	Image* contrast(Image *input, const float rate)
	{
		const int width = input->width;
		const int height = input->height;
		long sum = 0;
		
		for (int x = 0; x < width; x++)
		{
			for (int y = 0; y < height; y++)
			{
				sum += input->get(x, y);
			}
		}

		const unsigned short center = sum/width/height*0.7;
		short r, g, b, r2, g2, b2, r3, g3, b3;
		short brightness;
		for (int x = 0; x < width; x++)
		{
			for (int y = 0; y < height; y++)
			{
				r = input->getR(x, y);
				g = input->getG(x, y);
				b = input->getB(x, y);
				brightness = (2*r+4*g+b)/7;

				if (brightness == 0)
				{
					r2 = g2 = b2 = 0;
				}
				else
				{
					r2 = r*center/brightness;
					g2 = g*center/brightness;
					b2 = b*center/brightness;
				}
				
				r3 = (r-r2)*rate+r2;
				g3 = (g-g2)*rate+g2;
				b3 = (b-b2)*rate+b2;

				r3 = r3 > 255 ? 255 : (r3 < 0 ? 0 : r3);
				g3 = g3 > 255 ? 255 : (g3 < 0 ? 0 : g3);
				b3 = b3 > 255 ? 255 : (b3 < 0 ? 0 : b3);
				
				input->setR(x, y, r3);
				input->setG(x, y, g3);
				input->setB(x, y, b3);
			}
		}
	
		return input;
	}
	
	Image* greyscale(Image *input)
	{
		const unsigned int width = input->width;
		const unsigned int height = input->height;
		unsigned char *data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));

		for (int y = 0; y < input->height; y++)
		{
			for (int x = 0; x < input->width; x++)
			{
				data[(y*width+x)*3] =input->get(x, y);
			}
		}
		
		free(input->data);
		input->data = data;
		return input;
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
	
	Image* monochrome(Image *input)
	{
		int arrBrightness[64];//幅4で64段階
		for (int i = 0; i < 64; i++) arrBrightness[i] = 0;
		
		for (int y = 0; y < input->height; y++) {
			for (int x = 0; x < input->width; x++) {
				arrBrightness[input->get(x, y)/4]++;
			}
		}
		int threshold = detectThreshold(arrBrightness, 64);
		
		for (int y = 1; y < input->height; y++) {
			for (int x = 1; x < input->width; x++) {
				if (input->get(x, y) < threshold*4) {
					input->set(x, y, 0);
				} else {
					input->set(x, y, 255);
				}
			}
		}
		
		return input;
	}
	
	Image* normalize(Image *input)
	{
		return normalize(input, 1);
	}

	Image* normalize(Image *input, const int R)
	{
		//TODO: 走査手順を最適化し、1回の走査で完了できるようにする

		const int S = (R*2+1)*(R*2+1);
		const unsigned int width = input->width;
		const unsigned int height = input->height;
		
		unsigned char *data = (unsigned char *)malloc(sizeof(unsigned char)*width*height*3);
		unsigned int totalR = 0, totalG = 0, totalB = 0;
		
		for (int y = R; y < height-R; y++)
		{
			for (int x = R; x < width-R; x++)
			{
				totalR = 0;
				totalG = 0;
				totalB = 0;
				
				for (int dy = -R; dy <= R; dy++) {
					for (int dx = -R; dx <= R; dx++) {
						totalR += input->getR(x+dx, y+dy);
						totalG += input->getG(x+dx, y+dy);
						totalB += input->getB(x+dx, y+dy);
					}
				}
				
				data[(y*width+x)*3  ] = totalR/S;
				data[(y*width+x)*3+1] = totalG/S;
				data[(y*width+x)*3+2] = totalB/S;
			}
		}
		
		free(input->data);
		input->data = data;
		return input;
	}
	
	Image* edge2(Image *input)
	{
		const unsigned int width = input->width;
		const unsigned int height = input->height;
		unsigned char *data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));
		
		for (int y = 1; y < height-1; y++)
		{
			for (int x = 1; x < width-1; x++)
			{
				int dif =
				input->getR(x-1, y) +
				input->getR(x+1, y) +
				input->getR(x, y-1) +
				input->getR(x, y+1) -
				input->getR(x, y)*4;
				
				if (dif > EDGE_EPS)
				{
					data[(y*width+x)*3] = 255;
				}
			}
		}
		
		free(input->data);
		input->data = data;
		return input;
	}
	
	Image* edge(Image *input)
	{
		const unsigned int width = input->width;
		const unsigned int height = input->height;
		unsigned char *data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));
		unsigned char dif;
		
		for (int y = 0; y < height; y++)
		{
			for (int x = 0; x < width-EDGE_SKIP; x++)
			{
				dif = (abs(input->getR(x, y) - input->getR(x+EDGE_SKIP, y))
					   +  abs(input->getG(x, y) - input->getG(x+EDGE_SKIP, y))
					   +  abs(input->getB(x, y) - input->getB(x+EDGE_SKIP, y))) / 3;
				if (dif > EDGE_EPS)
				{
					data[(y*width+x)*3] = 255;
					x += EDGE_SKIP;
				}
			}
		}

		for (int x = 0; x < width; x++)
		{
			for (int y = 0; y < height-EDGE_SKIP; y++)
			{
				dif = (abs(input->getR(x, y) - input->getR(x, y+EDGE_SKIP))
					   +  abs(input->getG(x, y) - input->getG(x, y+EDGE_SKIP))
					   +  abs(input->getB(x, y) - input->getB(x, y+EDGE_SKIP))) / 3;
				if (dif > EDGE_EPS)
				{
					data[(y*width+x)*3] = 255;
					y += EDGE_SKIP;
				}
			}
		}

		free(input->data);
		input->data = data;
		return input;
	}
	
	Image* thiness(Image *input)
	{
		const unsigned int width = input->width;
		const unsigned int height = input->height;

		const unsigned char T = 255;
		const unsigned char F = 0;
		
		unsigned char *data = (unsigned char *)malloc(sizeof(unsigned char *)*width*height*3);
		memcpy(data, input->data, width*height*3);
		
		unsigned char p[9];
		bool flagEnd = true;
		
		while (true)
		{
			//サイクル1
			flagEnd = true;
			for (int y = 1; y < height-1; y++)
			{
				for (int x = width-2; x >= 1; x--)
				{
					for (int dy = -1; dy <= 1; dy++)
					{
						for (int dx = -1; dx <= 1; dx++)
						{
							p[4+dy*3+dx] = input->getR(x+dx, y+dy);
						}
					}
					
					if (p[4] == F) continue;
					
					if (p[1] == T && p[5] == T) continue;

					bool flagSkip =
					(p[1] == F && p[5] == T && p[7] == T && p[8] == F) ||
					(p[0] == F && p[1] == T && p[3] == T && p[5] == F) ||

					(p[3] == F && p[5] == F && p[7] == T) ||
					(p[1] == F && p[3] == T && p[7] == F) ||
					(p[1] == T && p[3] == F && p[5] == F) ||
					(p[1] == F && p[5] == T && p[7] == F) ||
					(p[3] == F && p[6] == T && p[7] == F) ||
					(p[0] == T && p[1] == F && p[3] == F) ||

					(p[1] == F && p[2] == T && p[5] == F) ||
					(p[5] == F && p[7] == F && p[8] == T) ||
					(p[0] == F && p[1] == T && p[2] == F && p[3] == T && p[5] == T && p[6] == F && p[8] == F) ||
					(p[0] == F && p[1] == T && p[2] == F && p[5] == T && p[6] == F && p[7] == T && p[8] == F) ||
					(p[0] == F && p[2] == F && p[3] == T && p[5] == T && p[6] == F && p[7] == T && p[8] == F) ||
					(p[0] == F && p[1] == T && p[2] == F && p[3] == T && p[6] == F && p[7] == T && p[8] == F);
					
					if (flagSkip) continue;

					data[(y*width+x)*3] = 0;
					flagEnd = false;
				}
			}
			if (flagEnd) break;
			memcpy(input->data, data, width*height*3);

			//サイクル2
			flagEnd = true;
			for (int y = height-2; y >= 1; y--)
			{
				for (int x = 1; x < width-1; x++)
				{
					for (int dy = -1; dy <= 1; dy++)
					{
						for (int dx = -1; dx <= 1; dx++)
						{
							p[4+dy*3+dx] = input->getR(x+dx, y+dy);
						}
					}
					
					if (p[4] == F) continue;
					
					if (p[7] == T && p[3] == T) continue;
					
					bool flagSkip =
					(p[0] == F && p[1] == T && p[3] == T && p[7] == F) ||
					(p[3] == F && p[5] == T && p[7] == T && p[8] == F) ||
					
					(p[3] == F && p[5] == F && p[7] == T) ||
					(p[1] == F && p[3] == T && p[7] == F) ||
					(p[1] == T && p[3] == F && p[5] == F) ||
					(p[1] == F && p[5] == T && p[7] == F) ||
					(p[3] == F && p[6] == T && p[7] == F) ||
					(p[0] == T && p[1] == F && p[3] == F) ||
					
					(p[1] == F && p[2] == T && p[5] == F) ||
					(p[5] == F && p[7] == F && p[8] == T) ||
					(p[0] == F && p[1] == T && p[2] == F && p[3] == T && p[5] == T && p[6] == F && p[8] == F) ||
					(p[0] == F && p[1] == T && p[2] == F && p[5] == T && p[6] == F && p[7] == T && p[8] == F) ||
					(p[0] == F && p[2] == F && p[3] == T && p[5] == T && p[6] == F && p[7] == T && p[8] == F) ||
					(p[0] == F && p[1] == T && p[2] == F && p[3] == T && p[6] == F && p[7] == T && p[8] == F);
					
					if (flagSkip) continue;
					
					input->setR(x, y, 0);
					flagEnd = false;
				}
			}
			if (flagEnd) break;
			memcpy(input->data, data, width*height*3);
		}

		return input;
	}
	
	Image* noizeCancel(Image *input, const unsigned int radius, const float density)
	{
		/*
			作戦:
			前回のcountをcount_oldとして、今回のcount_newは
		 	count_new = count_old - left + right となる。
		 	左端、右端だけ調べればよいはず。
		 
		 	また、そもそも明点でない場合は走査するまでもない。
		 	その場合は処理をスキップできるが、上記の短縮化は使えなくなるため、
		 	flagSkipedフラグを用いてスキップをした直後のみフルスキャンを行う。
		*/
		
		const unsigned int width = input->width;
		const unsigned int height = input->height;
		const unsigned int border = density * (2*radius+1);
		bool flagSkiped = true;
		unsigned int count = 0;
		
		unsigned char *data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));
		
		for (int cy = radius; cy < height - radius; cy++)
		{
			for (int cx = radius; cx < width - radius; cx++)
			{
				if (input->getR(cx, cy) != 255)
				{
					flagSkiped = true;
					continue;
				}
				
				if (flagSkiped)
				{
					count = 0;
					
					for (int x = cx-radius; x <= cx+radius; x++) {
						for (int y = cy-radius; y <= cy+radius; y++) {
							if (input->getR(x, y) == 255)
							{
								count++;
							}
						}
					}
		
					flagSkiped = false;
				}
				else
				{
					int xLeft = cx-radius-1;
					int xRight = cx+radius;
					
					for (int y = cy-radius; y <= cy+radius; y++)
					{
						if (input->getR(xLeft, y) == 255)
						{
							count--;
						}
						
						if (input->getR(xRight, y) == 255)
						{
							count++;
						}
					}
				}
				
				if (count >= border)
				{
					data[(cy*width+cx)*3]   = 255;
				}
			}
		};
		
		free(input->data);
		input->data = data;
		return input;
	}

	Image* expand(Image *input)
	{
		const unsigned int width = input->width;
		const unsigned int height = input->height;
		unsigned char lMax = 0;
		unsigned char mMax = 0;
		unsigned char rMax = 0;
		unsigned char max = 0;
		unsigned char blight;
		unsigned char *data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));

		for (int y = 1; y <height-1; y++)
		{
			for (int dy = -1; dy <= 1; dy++)
			{
				blight = input->getR(0, y+dy);
				if (blight > max) max = blight;
			}
			lMax = max;
			mMax = 0;
			rMax = 0;
			
			for (int x = 1; x <width-1; x++)
			{
				max = (mMax > rMax) ? mMax : rMax;
				lMax = mMax;
				mMax = rMax;
				rMax = 0;

				for (int dy = -1; dy <= 1; dy++)
				{
					blight = input->getR(x+1, y+dy);
					if (blight > rMax) rMax = blight;
				}
				
				if (rMax > max)
				{
					max = rMax;
				}
				
				data[(y*width+x)*3] = max;
			}
		}

		free(input->data);
		input->data = data;
		return input;
	}
	
	Image* contract(Image *input)
	{
		const unsigned int width = input->width;
		const unsigned int height = input->height;
		unsigned char lMin = 255;
		unsigned char mMin = 255;
		unsigned char rMin = 255;
		unsigned char min = 255;
		unsigned char blight;
		unsigned char *data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));
		
		for (int y = 1; y <height-1; y++)
		{
			for (int dy = -1; dy <= 1; dy++)
			{
				blight = input->getR(0, y+dy);
				if (blight < min) min = blight;
			}
			lMin = min;
			mMin = 255;
			rMin = 255;
			
			for (int x = 1; x <width-1; x++)
			{
				min = (mMin < rMin) ? mMin : rMin;
				lMin = mMin;
				mMin = rMin;
				rMin = 255;
				
				for (int dy = -1; dy <= 1; dy++)
				{
					blight = input->getR(x+1, y+dy);
					if (blight < rMin) rMin = blight;
				}
				
				if (rMin < min)
				{
					min = rMin;
				}
				
				data[(y*width+x)*3] = min;
			}
		}
		
		free(input->data);
		input->data = data;
		return input;
	}
}

