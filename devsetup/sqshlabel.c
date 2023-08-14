#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include "squashfs_fs_4.4.h"

#define SQSHLABEL "SquashfsLabel:"
#define SQSHLABELSIZE 14

struct squashfs_super_block super;

char *findlabel(int fd);
int   writelabel(int fd, char *label, int offset);

void syntax(char *cmdname)
{
	fprintf(stdout,"Usage: %s <image file> [label]\n");
}

int isValidLabelChar(int ch)
{

	if(ch>='a' && ch<='z') return 1;
	if(ch>='A' && ch<='Z') return 1;
	if(ch>='0' && ch<='9') return 1;
	if(ch=='_' || ch=='-') return 1;
	return 0;
}

int checkSquashFs(int fd)
{
	lseek(fd,0,SEEK_SET);
	if(read(fd, &super, sizeof(super))<sizeof(super)){
		fprintf(stderr,"Cound not read super block\n");
		return 0;
	}
	if(super.s_magic != SQUASHFS_MAGIC) return 0;

	fprintf(stderr,"Magic: %x\n", super.s_magic);
	fprintf(stderr,"Bytes Used: %lld\n", super.bytes_used);
	
	return 1;
}

int main(int argc, char **argv)
{
char *label;
int fd,c;

	if(argc<2){
		syntax(argv[0]);
		exit(0);
	}

	if((fd=open(argv[1], O_RDWR))<0){
		fprintf(stderr,"Could not open file %s\n", argv[1]);
		exit(-1);
	};

	if(checkSquashFs(fd)==0){
		fprintf(stderr,"Not a squashfs file\n");
		exit(-1);
	}

	if(argc==2){
		label=findlabel(fd);
		if(label==NULL){
			fprintf(stderr,"Could not find a label\n");
			exit(-1);
		}
		fprintf(stdout,"%s\n", label);
		exit(0);
	}else{
		for(c=0;c<=192;c++){
			if((argv[2])[c]==0) break;
			if(!isValidLabelChar((argv[2])[c])){
				fprintf(stderr,"Invalid label %s\n", argv[2]);
				exit(-1);
			}
		}

		if(c>=192){
			fprintf(stderr,"Label too long (max=192 characters)\n");
			exit(-1);
		}

		if(writelabel(fd, argv[2], -256)){
			fprintf(stderr,"Could not write label\n");
			exit(-1);
		};
	}
}


char *findlabel(int fd)
{
char buffer[256],*p;
int  count, bytes;

	if(lseek(fd, super.bytes_used, SEEK_SET)<0){
		fprintf(stderr,"Could not seek to the label offset (super.bytes_used)\n");
		return NULL;
	};

	if((bytes=read(fd,buffer,256))<256){
		fprintf(stderr,"Could not read label at end of file\n");
		return NULL;
	};

	if(strncmp(SQSHLABEL,buffer,SQSHLABELSIZE)==0){
		p=buffer;
		count=0;
		while(isValidLabelChar(*(p+SQSHLABELSIZE)) && count<192){
			*p = *(p+SQSHLABELSIZE);
			p++;
			count++;
		}		
		*p=0;
		return strdup(buffer);
	}

	return NULL;
}

int writelabel(int fd, char *label, int offset)
{
char buffer[8192];
long long  size, newsize,pad;

	memset(buffer, 0, 8192);
	size = snprintf(buffer, 8192, SQSHLABEL "%-192s", label);

	newsize = size + super.bytes_used;
	pad = ((newsize + 4095) / 4096) * 4096;
	fprintf(stdout,"newsize: %lld\n", pad);

	if(lseek(fd, super.bytes_used, SEEK_SET)<0){
		fprintf(stderr,"Could not seek to the label offset (super.butes_used)\n");
		return -1;
	};

	if(write(fd, buffer, pad - super.bytes_used)>0){
		return 0;
	};

	return -1;
}
