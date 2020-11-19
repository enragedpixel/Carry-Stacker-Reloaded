'''Install the Carry-Stacker-Reloaded mod

This file is meant to help during the development process. It will 
copy the mod files into the corresponding PAYDAY2/mods folder.

To configure it, change MODS_DIR to the corresponding 
steamapps/commons/PAYDAY2/mods path.

Author: m-alorda
'''
import sys
from pathlib import Path
import shutil

# Path to the PAYDAY2/mods directory
MODS_DIR = Path('F:/SteamLibrary/steamapps/common/PAYDAY 2/mods/')

# Using resolve to get an absoule path
INSTALL_FILE = Path(__file__).resolve()
DEVELOPMENT_DIR = INSTALL_FILE.parent


def copy(src, dest):
    '''Copy a file/directory into the given directory

    Copy recursively the files/directories in src into the dest 
    directory. For example, a given a file system such as:
    /foo
        /bar
            eggs
        jam
    /dest

    The result of copy(pathlib.Path('/foo'), pathlib.Path('/dest')) 
    would be:
    /dest
        /foo
            /bar
                eggs
            jam

    Arguments:
        src: A pathlib.Path instance pointing to the source 
            directory/file to be copied
        dest: A pathlib.Path instance pointing to the directory that 
            will contain the directories/files copied
    '''
    # Ignore hidden files such as .git, .github, .gitignore...
    # And dont copy the install file itself
    if src.name.startswith('.') or src.name == INSTALL_FILE.name:
        return
    elif src.is_file():
        print(f'Copying "{src}" into "{dest}"')
        shutil.copy(src, dest)
    else: # src is a directory
        nextDest = dest / src.name
        print(f'Creating dir "{nextDest}"')
        nextDest.mkdir()
        for file in src.iterdir():
            copy(file, nextDest)

def main():
    if not MODS_DIR.is_dir():
        print(f'The given PAYDAY2/mods directory does not exist: "{MODS_DIR}"')
        print(f'Please, change the value of "MODS_DIR" to the correct '
            + 'PAYDAY2/mods install path')
        sys.exit(1)

    print(f'The PAYDAY2/mods dir is: "{MODS_DIR}"')
    print(f'The development dir is: "{DEVELOPMENT_DIR}"')

    print(f'Deleting the PAYDAY2/mods/{DEVELOPMENT_DIR.name} if exists')
    shutil.rmtree(MODS_DIR / DEVELOPMENT_DIR.name, ignore_errors=True)

    copy(DEVELOPMENT_DIR, MODS_DIR)


if __name__ == '__main__':
    main()