# consistent Commenting is Very important
import os
import re

def lowercase_lua_comments_in_file(path):
    comment_pattern = re.compile(r'(--.*)')

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        match = comment_pattern.search(line)
        if match:
            comment = match.group(1)
            lower_comment = comment.lower()
            new_line = line[:match.start(1)] + lower_comment + line[match.end(1):]
            new_lines.append(new_line)
        else:
            new_lines.append(line)

    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print(f"Processed: {path}")

def main():
    for filename in os.listdir('.'):
        if filename.endswith('.lua') and os.path.isfile(filename):
            lowercase_lua_comments_in_file(filename)

if __name__ == "__main__":
    main()
