//
//  Image.cpp
//  pdfbinder
//
//  Created by kikurage on 2014/11/08.
//  Copyright (c) 2014年 KikuraYuichiro. All rights reserved.
//

#include "Image.h"

Image::Image(unsigned int width, unsigned int height)
{
	this->height = height;
	this->width = width;
	this->data = (unsigned char *)calloc(width*height*3, sizeof(unsigned char));
}

Image::~Image()
{
	free(this->data);
}

Image* Image::copy()
{
	Image *image = new Image(this->width, this->height);
	memcpy(image->data, this->data, this->width*this->height*3);
	
	return image;
}

unsigned char Image::getR(unsigned int x, unsigned int y)
{
	return	this->data[(this->width*y+x)*3];
}

unsigned char Image::getG(unsigned int x, unsigned int y)
{
	return	this->data[(this->width*y+x)*3+1];
}

unsigned char Image::getB(unsigned int x, unsigned int y)
{
	return	this->data[(this->width*y+x)*3+2];
}

void Image::setR(unsigned int x, unsigned int y, unsigned char value)
{
	this->data[(this->width*y+x)*3] = value;
}

void Image::setG(unsigned int x, unsigned int y, unsigned char value)
{
	this->data[(this->width*y+x)*3+1] = value;
}

void Image::setB(unsigned int x, unsigned int y, unsigned char value)
{
	this->data[(this->width*y+x)*3+2] = value;
}

unsigned char Image::get(unsigned int x, unsigned int y)
{
	return (this->getR(x, y)*2+this->getG(x, y)*4+this->getB(x, y))/7;
}

void Image::set(unsigned int x, unsigned int y, unsigned char value)
{
	this->setR(x, y, value);
	this->setG(x, y, value);
	this->setB(x, y, value);
}
