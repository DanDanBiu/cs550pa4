#include<stdio.h> 
#include<string.h>
#define BUFSIZE 5600
#define FAILURE -1
#define SUCCESS 0
int
main(int argc, char *argv[])
{
    void search_pattern(char *buf, char *pattern);
    char buf[BUFSIZE];
    char pattern[BUFSIZE];
    char file_name[BUFSIZE];
    FILE *fp;
    /*get the command line arguments into local variables */
    memset(pattern, 0, BUFSIZE);
    memset(buf, 0, BUFSIZE);
    memset(file_name, 0, BUFSIZE);
    strcpy(pattern, argv[2]);
    strcpy(file_name, argv[1]);
    /* open the file in read mode */
    fp=(FILE *)fopen(file_name, "r");
    if(fp==NULL)
    {
        /* return in case of failure */
        perror("fopen():");
        return FAILURE;
    }
    /* read one line from the file till end of file is reached */
    while(fgets(buf, BUFSIZE, fp)!=NULL)
    {
        search_pattern(buf, pattern);
    }
    fclose(fp);
    return SUCCESS;
}
void search_pattern(char *buf, char *pattern)
{
    char *p, *q, *s;
    for(p=buf, q=pattern; *p!='\0'; p++)
    {
        if(*p != *q)
            continue;
        else
        {
			s=p;
            for( ; *p==*q; p++, q++);
            if(*q=='\0')
            {
				
                /* pattern found. print it */
                printf("%s", buf);
                return;
            }
	    	p=s;
            q=pattern;
        }
    }
}
