/* X-Chat Aqua
 * Copyright (C) 2008 Eugene Pimenov
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA */

#include <dirent.h>

#include "outbound.h"
#define PLUGIN_C
typedef struct session xchat_context;
#include "xchat-plugin.h"
#include "plugin.h"

#import "SystemVersion.h"

static xchat_plugin *ph;

static void bundle_loader_load_bundle( char * word[], char * word_eol[])
{
    char * arg;
    
    arg = NULL;
    if (word_eol[3][0])
        arg = word_eol[3];
    
    NSString *bundle_path = [NSString stringWithUTF8String:word[2]];
    NSBundle *bundle = [NSBundle bundleWithPath:bundle_path];
    
    if(bundle == nil)
        return;
    
    do {
        NSString *path = [bundle executablePath];
        const char *filename = [path fileSystemRepresentation];
        
        NSString *version = [[bundle infoDictionary] objectForKey:@"XChatAquaMacOSVersionBranch"];
        if(version != nil && [[SystemVersion systemBranch] compare:version options:NSNumericSearch] != NSOrderedSame) {
            break;
        }
        
        char *error = plugin_load(current_sess, (char *)filename, arg);
        if(error != NULL) {
            xchat_print(ph, error);
        }
    } while(0); // while 0??
}

static int bundle_loader_load(char *word[], char *word_eol[], void *userdata)
{
    int len = strlen(word[2]);
    if (len > 7 && strcasecmp(".bundle", word[2]+len-7) == 0) {
        bundle_loader_load_bundle(word, word_eol);
        return XCHAT_EAT_XCHAT;
    }
    return XCHAT_EAT_NONE;
}


//Tries to load all files in plugins dir
void bundle_loader_auto_load(NSString *plugins_dir, int load_package)
{
    DIR * dir;
    
    dir = opendir([plugins_dir UTF8String]);
    if(!dir)
        return;
    for ( struct dirent *de=readdir(dir); de!=NULL; de=readdir(dir)) {
        if (de->d_name[0] == '.') continue; // ignore .*
        if (de->d_namlen == 2 && de->d_name[1] == 0) continue; // which case??
        
        int is_package = (de->d_namlen > 7 && strcasecmp(".bundle", de->d_name+de->d_namlen-7) == 0);
        is_package |= (de->d_namlen > 3 && strcasecmp(".so", de->d_name+de->d_namlen-3) == 0 );
        if (load_package == is_package) {
            NSString *cmd = [NSString stringWithFormat:@"LOAD \"%@/%@\"", plugins_dir, [NSString stringWithUTF8String:de->d_name]];
            handle_command (current_sess, (char *) [cmd UTF8String], FALSE);
        }
    }
    
    closedir(dir);
}

int bundle_loader_init (xchat_plugin *plugin_handle, char **plugin_name,
                        char **plugin_desc, char **plugin_version, char *arg)
{
    /* we need to save this for use with any xchat_* functions */
    ph = plugin_handle;
    
    *plugin_name = (char*)"Bundle loader";
    *plugin_desc = (char*)PRODUCT_NAME" Bundle loader";
    *plugin_version = (char*)"";
    
    xchat_hook_command (ph, "LOAD", XCHAT_PRI_NORM, bundle_loader_load, 0, 0);
    
    NSString *builtInPlugInsPath = [[NSBundle mainBundle] builtInPlugInsPath];
    bundle_loader_auto_load(builtInPlugInsPath, true);
    
    NSString *applicationSupportPlugInsPath = [[SGFileUtility findApplicationSupportFor:@PRODUCT_NAME] stringByAppendingPathComponent:@"PlugIns"];
    bundle_loader_auto_load(applicationSupportPlugInsPath, true);
    bundle_loader_auto_load(applicationSupportPlugInsPath, false);
    
    return 1;       /* return 1 for success */
}
