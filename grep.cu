#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#define MAX_VALUE 5600
#define MAX_STRING_LENGTH 4096
#define CHECK_ERR(x)                                    \
	if (x != cudaSuccess) {                               \
		fprintf(stderr,"%s in %s at line %d\n",             \
				cudaGetErrorString(err),__FILE__,__LINE__); \
		exit(-1);                                           \
	}                                                     \
	
//	global variables: 
//	d_A: the huge string buffer in GPU
//	d_B: start position of each line in d_A
//	d_C: length of each line in d_A
//	d_D: stores the pattern in GPU 
char *d_A;
int *d_B;
int *d_C;
char *d_D;
cudaError_t err;

//kernel function: each thread gets its corresponding line and search the pattern in the naive way.
__global__ void grep (char* d_A, int * d_B, int * d_C, char * d_D, int arrayLength,int patternLength ) {
	//	get the index of the thread.
	int threadIndex = blockDim.x * blockIdx.x + threadIdx.x;
	//	only the thread whose index is less than the 4096 does the search
	if (threadIndex < arrayLength) {
		int flag = 1;
		// match algorithm: naive
		// if the length of each substring is less than the size of the pattern, there is certainly no match. Just return
		if(d_C[threadIndex] <patternLength ){
			flag=0;
			return;
		}
		else {
			//	use a for loop to search from every possible position.
			for(int i = d_B[threadIndex]; i < d_B[threadIndex] + d_C[threadIndex] + 1 - patternLength  ; i ++ ){
				flag =1;
				int k = i ;
				for( int j = 0 ; j < patternLength && flag == 1 ; j ++ ) {
					if(d_A[k + j ]!= d_D[j])
						flag = 0;
				}
				// if match ,print and return.
				if(flag==1) {
					printf("%s\n",d_A+d_B[threadIndex]);
					return ;
				}

			}
		}
	}

}


// allocate GPU memory, only 4 blocks of memory in GPU are required.
void allocDeviceMemory(int totalstringSize ){
	
	err = cudaMalloc((char **) &d_A, sizeof(char)*MAX_STRING_LENGTH*MAX_VALUE);
	CHECK_ERR(err);

	err = cudaMalloc((int **) &d_B, sizeof(int)*MAX_STRING_LENGTH);
	CHECK_ERR(err);

	err = cudaMalloc((int **) &d_C, sizeof(int)*MAX_STRING_LENGTH );
	CHECK_ERR(err);
	
	err = cudaMalloc((char **) &d_D, sizeof(char)*MAX_STRING_LENGTH );
	CHECK_ERR(err);


}

// copy the string buffer, start position array and string length array to GPU.
void copytoDeviceMemory(char * result, int * start, int * stringSize, char * pattern, int totalstringSize){
	err = cudaMemcpy(d_A, result, sizeof(char)*totalstringSize, cudaMemcpyHostToDevice);
	CHECK_ERR(err);
	err = cudaMemcpy(d_B, start, sizeof(int)*MAX_STRING_LENGTH, cudaMemcpyHostToDevice);
	CHECK_ERR(err);
	err = cudaMemcpy(d_C, stringSize, sizeof(int)*MAX_STRING_LENGTH, cudaMemcpyHostToDevice);
	CHECK_ERR(err);

}

// before terminates the program, free the GPU memory.
void freeDeviceMemory()
{
	cudaFree(d_A);
	cudaFree(d_B);
	cudaFree(d_C);
	cudaFree(d_D);
}



int main(int argc, char *argv[])
{
	int  lineNumber, n;
	FILE *f;
	f = fopen(argv[1], "r");
	if (f == NULL) {
		printf("can't open %s:", argv[1]);
	}
	
	// 	result is the huge string buffer in CPU end
	//	pattern is the string you are looking for.
	//	start array stores the start position of each string in the buffer.
	//	stringSize sotres each string's real length.
	//	totalstringSize records the total lengths of the current 4096 lines of string.
	char * result = (char *)malloc(sizeof(char)*MAX_VALUE * MAX_STRING_LENGTH);
	char * pattern = (char *)malloc(sizeof(char)*MAX_VALUE);
	int start[MAX_STRING_LENGTH];
	int stringSize[MAX_STRING_LENGTH];
	int totalstringSize=0;


	//	line number the line index the current file descriptor is reading.
	lineNumber = 0;
	n=0;

	// initializing...
	for(int i = 0; i < MAX_STRING_LENGTH; i ++ ) {
		start[i] = 0;
		stringSize[i] = 0;
	}
	totalstringSize = 0;
	strcat(pattern,argv[2]);
	
	
	
	//	allocate memory in GPU.
	allocDeviceMemory(totalstringSize);
	//	pattern only needs to be copied to GPU once. Thus do it first.
	err = cudaMemcpy(d_D, pattern, sizeof(char)*strlen(pattern), cudaMemcpyHostToDevice);
	CHECK_ERR(err);
	
	// 	each while loop ,we read 4096 lines of strings to the buffer string.
	while (fgets(result+start[lineNumber%MAX_STRING_LENGTH], MAX_VALUE, f) != NULL) {

		n = strlen(result+start[lineNumber%MAX_STRING_LENGTH]);

		
		//	save the current string to the huge buffer string
		if (n > 0 && *(result+start[lineNumber%MAX_STRING_LENGTH] + n-1) == '\n'){
			*(result+start[lineNumber%MAX_STRING_LENGTH] + n-1) = '\0';
		}

		//	save the correct start position and string length.
		if(lineNumber%MAX_STRING_LENGTH < MAX_STRING_LENGTH-1) {
			stringSize[lineNumber%MAX_STRING_LENGTH]=n;
			start[lineNumber%MAX_STRING_LENGTH + 1] = start[lineNumber%MAX_STRING_LENGTH] + stringSize[lineNumber%MAX_STRING_LENGTH];
		}
		else {
			stringSize[lineNumber%MAX_STRING_LENGTH]=n;
		}
		totalstringSize += n;
		lineNumber ++;

		//	send the 4096 lines to GPU and do the searching.
		if(lineNumber % MAX_STRING_LENGTH == 0) {
			//	copy first
			copytoDeviceMemory(result,  start, stringSize,  pattern, totalstringSize);
			grep<<<16,256>>>(d_A, d_B, d_C, d_D, MAX_STRING_LENGTH,strlen(pattern));
			//	reset the buffer and other variables.
			memset(result,'\0',sizeof(result));
			totalstringSize = 0;
			start[0]=0;
		}
	}

	//	send the remaining lines to GPU and do the searching.
	if(lineNumber % MAX_STRING_LENGTH !=0) {
		copytoDeviceMemory(result,  start, stringSize,  pattern, totalstringSize);
		//	only copy lineNumber%MAX_STRING_LENGTH strings to GPU.
		grep<<<16,256>>>(d_A, d_B, d_C, d_D,lineNumber % MAX_STRING_LENGTH,strlen(pattern) );
		//	free the memory finally
		freeDeviceMemory();
	}

	return 0;
}
