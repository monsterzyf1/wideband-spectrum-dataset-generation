function ClassName = RandomPickClass(ClassList, Prob)

p = rand;
acc = 0;

for k = 1:length(ClassList)
    acc = acc + Prob(k);
    if p <= acc
        ClassName = ClassList{k};
        return;
    end
end

ClassName = ClassList{end};

end