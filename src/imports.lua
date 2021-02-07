-- See unminified versions in src/imports
return {
    debug = [[local _debug;do local a=table.insert;local b=table.concat;local c=string.len;local d=string.find;local e=string.rep;local function f(g)local h,i,j={},{},{}local k=1;local l="{\n"while true do local m=0;for n,o in pairs(g)do m=m+1 end;local p=1;for n,o in pairs(g)do if h[g]==nil or p>=h[g]then if d(l,"}",c(l))then l=l..",\n"elseif not d(l,"\n",c(l))then l=l.."\n"end;a(j,l)l=""local q;if type(n)=="number"or type(n)=="boolean"then q="["..tostring(n).."]"else q="['"..tostring(n).."']"end;if type(o)=="number"or type(o)=="boolean"then l=l..e('\t',k)..q.." = "..tostring(o)elseif type(o)=="table"then l=l..e('\t',k)..q.." = {\n"a(i,g)a(i,o)h[g]=p+1;break else l=l..e('\t',k)..q.." = '"..tostring(o).."'"end;if p==m then l=l.."\n"..e('\t',k-1).."}"else l=l..","end else if p==m then l=l.."\n"..e('\t',k-1).."}"end end;p=p+1 end;if m==0 then l=l.."\n"..e('\t',k-1).."}"end;if#i>0 then g=i[#i]i[#i]=nil;k=h[g]==nil and k+1 or k-1 else break end end;a(j,l)return b(j)end;function _debug(...)local r={...}for s,o in pairs(r)do if type(o)=="table"then r[s]=f(o)end end;print(unpack(r))end end]],

    concat = "local concat = table.concat",
    insert = "local insert = table.insert",
    remove = "local remove = table.remove",

    random = "math.randomseed(os.time());local random = math.random"
}
