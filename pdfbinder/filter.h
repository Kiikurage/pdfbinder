//
//  filter.h
//  pdfbinder
//
//  Created by kikurage on 2014/11/08.
//  Copyright (c) 2014年 KikuraYuichiro. All rights reserved.
//

#ifndef __pdfbinder__filter__
#define __pdfbinder__filter__

#include <stdio.h>
#include <math.h>
#include "./Image.h"

#define EDGE_EPS 50
#define EDGE_SKIP 10

namespace Filter {
	Image* contrast(Image *input, const float rate);
	Image* greyscale(Image *input);
	Image* monochrome(Image *input);

	Image* normalize(Image *input, int radius);
	Image* normalize(Image *input);
	
	Image* edge(Image *input);
	Image* thiness(Image *thiness);
	Image* noizeCancel(Image *input, const unsigned int radius, const float density);
	Image* expand(Image *input);
	Image* contract(Image *input);
}

#endif /* defined(__pdfbinder__filter__) */
