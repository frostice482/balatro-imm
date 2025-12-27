struct SharedData {
	int id;
	int gid;
	int remaining;
	bool abort;
};

// for fast copy

typedef struct FILE FILE;
typedef struct PHYSFS_File PHYSFS_File;

PHYSFS_File* PHYSFS_openRead(const char* filename);
long long PHYSFS_readBytes(PHYSFS_File* handle, void* buffer, unsigned long long len);
int PHYSFS_close(PHYSFS_File* handle);

FILE* fopen(const char* restrict path, const char *restrict mode);
size_t fread(void* restrict buffer, size_t size, size_t count, FILE* restrict stream);
size_t fwrite(void* restrict buffer, size_t size, size_t count, FILE* restrict stream);
int ferror(FILE* stream);
int fclose(FILE* stream);