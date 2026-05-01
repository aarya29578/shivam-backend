import sys
p='d:/Shivam-bitch/edumid/lib/features/student/screens/student_attendance_screen.dart'
with open(p,encoding='utf-8') as f:
    s=f.read()

pairs={')':'(',']':'[','}':'{'}
stack=[]
line=1
col=0
for i,ch in enumerate(s):
    if ch=='\n':
        line+=1
        col=0
        continue
    col+=1
    if ch in '([{':
        stack.append((ch,line,col))
    elif ch in ')]}':
        if not stack:
            print(f"Unmatched closing {ch} at {line}:{col}")
            # show context
            lines = s.splitlines()
            start = max(1, line-3)
            end = min(len(lines), line+3)
            print('\nContext around unmatched closing:')
            for ln in range(start, end+1):
                prefix = '>' if ln==line else ' '
                print(f"{prefix} {ln:4}: {lines[ln-1]}")
            sys.exit(1)
        top,tl,tc=stack.pop()
        if top!=pairs[ch]:
            print(f"Mismatched {top} at {tl}:{tc} closed by {ch} at {line}:{col}")
            # show context around the original opening
            start = max(1, tl-3)
            end = tl+3
            print('\nContext around opening:')
            lines = s.splitlines()
            for ln in range(start, min(end, len(lines))+1):
                prefix = '>' if ln==tl else ' '
                print(f"{prefix} {ln:4}: {lines[ln-1]}")
            print('\nContext around closing:')
            start2 = max(1, line-3)
            end2 = line+3
            for ln in range(start2, min(end2, len(lines))+1):
                prefix = '>' if ln==line else ' '
                print(f"{prefix} {ln:4}: {lines[ln-1]}")
            sys.exit(1)

if stack:
    for ch,tl,tc in stack:
        print(f"Unclosed {ch} at {tl}:{tc}")
    sys.exit(1)
print('Balanced')
