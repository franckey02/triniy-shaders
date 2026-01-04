#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>

// JSON parsing would require a library in real implementation
// For simplicity, I'll use placeholder functions
#define MAX_PATH 1024
#define MAX_PACKS 100
#define MAX_NAME 256

typedef struct {
    char uuid[64];
    char version[32];
    char path[MAX_PATH];
    char name[MAX_NAME];
    int is_development;
} ResourcePack;

typedef struct {
    ResourcePack packs[MAX_PACKS];
    int count;
} PackList;

// Placeholder functions for JSON parsing
// In a real implementation, you'd use cJSON or jansson library
int parse_uuid_from_manifest(const char* path, char* uuid) {
    // Simplified: would parse actual JSON
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    
    // Mock parsing - real implementation would use JSON parser
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"uuid\"")) {
            // Extract UUID from line
            char* start = strchr(line, ':');
            if (start) {
                start = strchr(start, '"');
                if (start) {
                    start++;
                    char* end = strchr(start, '"');
                    if (end) {
                        *end = '\0';
                        strncpy(uuid, start, 63);
                        fclose(f);
                        return 1;
                    }
                }
            }
        }
    }
    fclose(f);
    return 0;
}

int parse_name_from_manifest(const char* path, char* name) {
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"name\"")) {
            char* start = strchr(line, ':');
            if (start) {
                start = strchr(start, '"');
                if (start) {
                    start++;
                    char* end = strchr(start, '"');
                    if (end) {
                        *end = '\0';
                        strncpy(name, start, 255);
                        fclose(f);
                        return 1;
                    }
                }
            }
        }
    }
    fclose(f);
    return 0;
}

int parse_version_from_manifest(const char* path, char* version) {
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"version\"")) {
            char* start = strchr(line, '[');
            if (start) {
                start++;
                char* end = strchr(start, ']');
                if (end) {
                    *end = '\0';
                    // Remove dots and spaces
                    char* p = start;
                    char* q = version;
                    while (*p) {
                        if (isdigit(*p)) {
                            *q++ = *p;
                        }
                        p++;
                    }
                    *q = '\0';
                    fclose(f);
                    return 1;
                }
            }
        }
    }
    fclose(f);
    return 0;
}

int parse_global_pack(const char* path, char* pack_id, char* version, char* subpack) {
    FILE* f = fopen(path, "r");
    if (!f) return 0;
    
    char line[256];
    int found_pack_id = 0, found_version = 0, found_subpack = 0;
    
    while (fgets(line, sizeof(line), f)) {
        if (!found_pack_id && strstr(line, "\"pack_id\"")) {
            char* start = strchr(line, '"');
            if (start) {
                start++;
                char* end = strchr(start, '"');
                if (end) {
                    *end = '\0';
                    strncpy(pack_id, start, 63);
                    found_pack_id = 1;
                }
            }
        }
        else if (!found_version && strstr(line, "\"version\"")) {
            char* start = strchr(line, '[');
            if (start) {
                start++;
                char* end = strchr(start, ']');
                if (end) {
                    *end = '\0';
                    // Extract version numbers
                    char* p = start;
                    char* q = version;
                    int num_count = 0;
                    while (*p && num_count < 3) {
                        if (isdigit(*p)) {
                            *q++ = *p;
                            if (*(p+1) && !isdigit(*(p+1))) {
                                num_count++;
                            }
                        }
                        p++;
                    }
                    *q = '\0';
                    found_version = 1;
                }
            }
        }
        else if (!found_subpack && strstr(line, "\"subpack\"")) {
            char* start = strchr(line, '"');
            if (start) {
                start++;
                char* end = strchr(start, '"');
                if (end) {
                    *end = '\0';
                    strncpy(subpack, start, 63);
                    found_subpack = 1;
                }
            }
        }
    }
    
    fclose(f);
    return found_pack_id && found_version;
}

// Remove Minecraft formatting codes
void clean_name(char* name) {
    char* src = name;
    char* dst = name;
    
    while (*src) {
        if (*src == '§') {
            src++; // Skip §
            if (*src) src++; // Skip the format code
        } else {
            *dst++ = *src++;
        }
    }
    *dst = '\0';
}

void scan_packs_directory(const char* base_path, PackList* pack_list, int is_development) {
    struct dirent* entry;
    DIR* dir = opendir(base_path);
    
    if (!dir) return;
    
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        
        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", base_path, entry->d_name);
        
        struct stat path_stat;
        stat(full_path, &path_stat);
        
        if (S_ISDIR(path_stat.st_mode)) {
            char manifest_path[MAX_PATH];
            snprintf(manifest_path, sizeof(manifest_path), "%s/manifest.json", full_path);
            
            if (access(manifest_path, F_OK) == 0) {
                // Found manifest.json
                if (pack_list->count >= MAX_PACKS) {
                    printf("[!] Too many packs, skipping some...\n");
                    break;
                }
                
                ResourcePack* pack = &pack_list->packs[pack_list->count];
                pack->is_development = is_development;
                strncpy(pack->path, full_path, MAX_PATH - 1);
                
                if (parse_uuid_from_manifest(manifest_path, pack->uuid) &&
                    parse_name_from_manifest(manifest_path, pack->name) &&
                    parse_version_from_manifest(manifest_path, pack->version)) {
                    
                    clean_name(pack->name);
                    pack_list->count++;
                    
                    printf("%d.\t%s%s\n", pack_list->count, pack->name, 
                           is_development ? " [DEVELOPMENT]" : "");
                } else {
                    printf("\n[!] Skipping: %s/manifest.json (UUID missing or invalid)\n\n", 
                           full_path);
                }
            } else {
                // Look for subdirectories
                DIR* subdir = opendir(full_path);
                if (subdir) {
                    struct dirent* subentry;
                    while ((subentry = readdir(subdir)) != NULL) {
                        if (subentry->d_name[0] == '.') continue;
                        
                        char sub_path[MAX_PATH];
                        snprintf(sub_path, sizeof(sub_path), "%s/%s", full_path, subentry->d_name);
                        
                        struct stat sub_stat;
                        stat(sub_path, &sub_stat);
                        
                        if (S_ISDIR(sub_stat.st_mode)) {
                            char sub_manifest[MAX_PATH];
                            snprintf(sub_manifest, sizeof(sub_manifest), "%s/manifest.json", sub_path);
                            
                            if (access(sub_manifest, F_OK) == 0) {
                                if (pack_list->count >= MAX_PACKS) {
                                    printf("[!] Too many packs, skipping some...\n");
                                    closedir(subdir);
                                    closedir(dir);
                                    return;
                                }
                                
                                ResourcePack* pack = &pack_list->packs[pack_list->count];
                                pack->is_development = is_development;
                                strncpy(pack->path, sub_path, MAX_PATH - 1);
                                
                                if (parse_uuid_from_manifest(sub_manifest, pack->uuid) &&
                                    parse_name_from_manifest(sub_manifest, pack->name) &&
                                    parse_version_from_manifest(sub_manifest, pack->version)) {
                                    
                                    clean_name(pack->name);
                                    pack_list->count++;
                                    
                                    printf("%d.\t%s%s\n", pack_list->count, pack->name, 
                                           is_development ? " [DEVELOPMENT]" : "");
                                } else {
                                    printf("\n[!] Skipping: %s/manifest.json (UUID missing or invalid)\n\n", 
                                           sub_path);
                                }
                            }
                        }
                    }
                    closedir(subdir);
                }
            }
        }
    }
    closedir(dir);
}

int find_active_pack(const PackList* pack_list, const char* pack_id, 
                     const char* version, ResourcePack** found_pack) {
    char search_key[128];
    snprintf(search_key, sizeof(search_key), "%s_%s", pack_id, version);
    
    // Convert to lowercase for comparison
    for (int i = 0; search_key[i]; i++) {
        search_key[i] = tolower(search_key[i]);
    }
    
    for (int i = 0; i < pack_list->count; i++) {
        char pack_key[128];
        snprintf(pack_key, sizeof(pack_key), "%s_%s", 
                 pack_list->packs[i].uuid, pack_list->packs[i].version);
        
        for (int j = 0; pack_key[j]; j++) {
            pack_key[j] = tolower(pack_key[j]);
        }
        
        if (strcmp(pack_key, search_key) == 0) {
            *found_pack = (ResourcePack*)&pack_list->packs[i];
            return 1;
        }
    }
    return 0;
}

void create_symlinks(const char* pack_path, const char* subpack_name, 
                     const char* shaders_path) {
    // Clean shaders directory
    DIR* dir = opendir(shaders_path);
    if (dir) {
        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            if (entry->d_name[0] == '.') continue;
            
            char file_path[MAX_PATH];
            snprintf(file_path, sizeof(file_path), "%s/%s", shaders_path, entry->d_name);
            remove(file_path);
        }
        closedir(dir);
    }
    
    // Create symlinks from main pack
    char materials_path[MAX_PATH];
    snprintf(materials_path, sizeof(materials_path), "%s/renderer/materials", pack_path);
    
    dir = opendir(materials_path);
    if (dir) {
        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            if (strstr(entry->d_name, ".material.bin")) {
                char src_path[MAX_PATH];
                char dst_path[MAX_PATH];
                snprintf(src_path, sizeof(src_path), "%s/%s", materials_path, entry->d_name);
                snprintf(dst_path, sizeof(dst_path), "%s/%s", shaders_path, entry->d_name);
                
                if (symlink(src_path, dst_path) != 0) {
                    printf("[!] Failed to create symlink for %s: %s\n", 
                           entry->d_name, strerror(errno));
                }
            }
        }
        closedir(dir);
    }
    
    // Create symlinks from subpack if exists
    if (subpack_name && subpack_name[0] != '\0') {
        char subpack_path[MAX_PATH];
        snprintf(subpack_path, sizeof(subpack_path), "%s/subpacks/%s/renderer/materials", 
                 pack_path, subpack_name);
        
        dir = opendir(subpack_path);
        if (dir) {
            struct dirent* entry;
            while ((entry = readdir(dir)) != NULL) {
                if (strstr(entry->d_name, ".material.bin")) {
                    char src_path[MAX_PATH];
                    char dst_path[MAX_PATH];
                    snprintf(src_path, sizeof(src_path), "%s/%s", subpack_path, entry->d_name);
                    snprintf(dst_path, sizeof(dst_path), "%s/%s", shaders_path, entry->d_name);
                    
                    // Remove existing symlink if exists
                    remove(dst_path);
                    
                    if (symlink(src_path, dst_path) != 0) {
                        printf("[!] Failed to create symlink for %s: %s\n", 
                               entry->d_name, strerror(errno));
                    }
                }
            }
            closedir(dir);
        }
    }
}

int directory_exists(const char* path) {
    struct stat statbuf;
    return (stat(path, &statbuf) == 0 && S_ISDIR(statbuf.st_mode));
}

int file_exists(const char* path) {
    return access(path, F_OK) == 0;
}

int main() {
    char mcpelauncher_root[MAX_PATH];
    char mcpelauncher_data[MAX_PATH];
    char shaders_path[MAX_PATH];
    
    // Detect which installation path exists
    const char* default_path = "/.local/share/mcpelauncher";
    const char* alt_path = "/.var/app/com.trench.trinity.launcher/data/mcpelauncher";
    
    char default_full[MAX_PATH];
    char alt_full[MAX_PATH];
    
    snprintf(default_full, sizeof(default_full), "%s%s", getenv("HOME"), default_path);
    snprintf(alt_full, sizeof(alt_full), "%s%s", getenv("HOME"), alt_path);
    
    if (directory_exists(default_full)) {
        strcpy(mcpelauncher_root, default_full);
        printf("[*] Using default path: %s\n", mcpelauncher_root);
    } else if (directory_exists(alt_full)) {
        strcpy(mcpelauncher_root, alt_full);
        printf("[*] Using alternative path: %s\n", mcpelauncher_root);
    } else {
        printf("[!] mcpelauncher not found in any known location\n");
        printf("    Searched in:\n");
        printf("    - %s\n", default_full);
        printf("    - %s\n", alt_full);
        return 1;
    }
    
    snprintf(mcpelauncher_data, sizeof(mcpelauncher_data), "%s/games/com.mojang", mcpelauncher_root);
    snprintf(shaders_path, sizeof(shaders_path), "%s/shaders", mcpelauncher_root);
    
    printf("\n");
    
    // Check for jq (would need to be implemented differently in C)
    // For now, we'll assume our JSON parsing functions work
    
    char global_packs_path[MAX_PATH];
    snprintf(global_packs_path, sizeof(global_packs_path), 
             "%s/minecraftpe/global_resource_packs.json", mcpelauncher_data);
    
    if (!file_exists(global_packs_path)) {
        printf("[!] global_resource_packs.json not found.\n");
        return 1;
    }
    
    PackList pack_list = {0};
    
    printf("[*] Getting resource pack list...\n\n");
    
    // Scan normal resource packs
    char resource_packs_path[MAX_PATH];
    snprintf(resource_packs_path, sizeof(resource_packs_path), 
             "%s/resource_packs", mcpelauncher_data);
    scan_packs_directory(resource_packs_path, &pack_list, 0);
    
    // Scan development resource packs
    char dev_packs_path[MAX_PATH];
    snprintf(dev_packs_path, sizeof(dev_packs_path), 
             "%s/development_resource_packs", mcpelauncher_data);
    scan_packs_directory(dev_packs_path, &pack_list, 1);
    
    printf("\n[*] Found %d packs\n\n", pack_list.count);
    
    // Parse active pack info
    char pack_id[64] = {0};
    char version[32] = {0};
    char subpack[64] = {0};
    
    if (!parse_global_pack(global_packs_path, pack_id, version, subpack)) {
        printf("[!] Failed to parse global_resource_packs.json\n");
        return 1;
    }
    
    printf("\n");
    
    // Find the active pack
    ResourcePack* active_pack = NULL;
    if (find_active_pack(&pack_list, pack_id, version, &active_pack)) {
        printf("First global pack name: %s v%s (%s)\n", 
               active_pack->name, version, pack_id);
        printf("Pack path: \t\t%s\n", active_pack->path);
        
        if (subpack[0] != '\0') {
            printf("hasSubpack:\t\ttrue\n");
            printf("Subpack path: \t\t%s/subpacks/%s\n", active_pack->path, subpack);
        } else {
            printf("hasSubpack:\t\tfalse\n");
        }
    } else {
        printf("[!] Active pack not found in scanned packs\n");
    }
    
    printf("\n");
    
    // Check shaders directory
    if (!directory_exists(shaders_path)) {
        printf("[!] shaders folder not found. Please create it yourself.\n");
        printf("    mkdir -p \"%s\"\n", shaders_path);
        return 1;
    }
    
    if (!active_pack) {
        printf("[!] No active pack found, emptying shaders folder...\n");
        // Clean shaders directory
        create_symlinks("", "", shaders_path);
        return 0;
    }
    
    // Check for material files
    int has_materials = 0;
    char materials_dir[MAX_PATH];
    
    snprintf(materials_dir, sizeof(materials_dir), "%s/renderer/materials", active_pack->path);
    DIR* dir = opendir(materials_dir);
    if (dir) {
        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            if (strstr(entry->d_name, ".material.bin")) {
                has_materials = 1;
                break;
            }
        }
        closedir(dir);
    }
    
    if (!has_materials && subpack[0] != '\0') {
        char subpack_materials[MAX_PATH];
        snprintf(subpack_materials, sizeof(subpack_materials), 
                 "%s/subpacks/%s/renderer/materials", active_pack->path, subpack);
        
        dir = opendir(subpack_materials);
        if (dir) {
            struct dirent* entry;
            while ((entry = readdir(dir)) != NULL) {
                if (strstr(entry->d_name, ".material.bin")) {
                    has_materials = 1;
                    break;
                }
            }
            closedir(dir);
        }
    }
    
    if (!has_materials) {
        printf("[!] No .material.bin files found in the pack.\n\n");
        printf("[*] Emptying shaders folder...\n\n");
        create_symlinks("", "", shaders_path);
        return 0;
    }
    
    // Create symlinks
    create_symlinks(active_pack->path, subpack, shaders_path);
    
    // Replace $HOME with $HOME in output
    char display_path[MAX_PATH];
    strcpy(display_path, shaders_path);
    char* home = getenv("HOME");
    if (home && strstr(display_path, home)) {
        char temp[MAX_PATH];
        snprintf(temp, sizeof(temp), "$HOME%s", display_path + strlen(home));
        strcpy(display_path, temp);
    }
    
    printf("[*] Symlinks to materials created in %s\n", display_path);
    printf("\nHave good day!\n\n");
    
    return 0;
}
