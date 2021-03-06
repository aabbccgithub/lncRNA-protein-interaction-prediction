function integratedLPLNP
    warning('off');
    result = zeros(1, 7);
    seed = 1;
    cross_validation(seed);
    
end

function result = cross_validation(seed)
    CV=5;
    
    load extracted_interaction.txt;
    load protein_ctd;
    load extracted_lncRNA_sequence_CT.txt
    load extracted_lncRNA_expression.txt
    
    interaction_matrix = extracted_interaction;
    CV=5;
    rand('state',seed);
    [row,col]=size(interaction_matrix);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [row_index,col_index]=find(interaction_matrix==1);
    link_num=sum(sum(interaction_matrix)); 
    rand('state',seed);
    random_index=randperm(link_num);
    size_of_CV=round(link_num/CV);                                                      
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    result=zeros(1,7);
    for k=1:CV
        fprintf('begin to implement the cross validation:round =%d/%d\n', k, CV);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if (k~=CV)
           test_row_index=row_index(random_index((size_of_CV*(k-1)+1):(size_of_CV*k)));
           test_col_index=col_index(random_index((size_of_CV*(k-1)+1):(size_of_CV*k)));
        else
          test_row_index=row_index(random_index((size_of_CV*(k-1)+1):end));
          test_col_index=col_index(random_index((size_of_CV*(k-1)+1):end));
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        train_set=interaction_matrix;
        test_link_num=size(test_row_index,1);
        for i=1:test_link_num
              train_set(test_row_index(i),test_col_index(i))=0;                 
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        similairty_matrix=Label_Propagation(train_set',0,6,'regulation2');    
        predict_p_interaction=calculate_labels(similairty_matrix,train_set',0.5)';
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        similairty_matrix=Label_Propagation(protein_ctd,0,23,'regulation2');    
        predict_p_ctd=calculate_labels(similairty_matrix,train_set',0.3)';
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        similairty_matrix=Label_Propagation(train_set,0,100,'regulation2');    
        predict_l_interaction=calculate_labels(similairty_matrix,train_set,0.7);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        similairty_matrix=Label_Propagation(extracted_lncRNA_sequence_CT,0,800,'regulation2');    
        predict_l_seq=calculate_labels(similairty_matrix,train_set,0.1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        similairty_matrix=Label_Propagation(extracted_lncRNA_expression,0,100,'regulation2');    
        predict_l_exp=calculate_labels(similairty_matrix,train_set,0.9);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        predict_matrix_LP = 0.4 * predict_p_interaction + 0.1 * predict_p_ctd + 0.3 * predict_l_interaction + 0.19 * predict_l_seq + 0.01 * predict_l_exp;
        result=result+model_evaluate(interaction_matrix,predict_matrix_LP,train_set);
        result/k                                                                        
    end
    result=result/CV;
    result
end


function result=model_evaluate(interaction_matrix,predict_matrix,train_ddi_matrix)
    real_score=interaction_matrix(:);
    predict_score=predict_matrix(:);
    index=train_ddi_matrix(:);
    test_index=find(index==0);
    real_score=real_score(test_index);
    predict_score=predict_score(test_index);
    aupr=AUPR(real_score,predict_score);
    auc=AUC(real_score,predict_score);
    [sen,spec,precision,accuracy,f1]=evaluation_metric(real_score,predict_score);
    result=[aupr,auc,sen,spec,precision,accuracy,f1];
end


function [sen,spec,precision,accuracy,f1]=evaluation_metric(interaction_score,predict_score)
    max_value=max(predict_score);
    min_value=min(predict_score);
    threshold=min_value+(max_value-min_value)*(1:999)/1000;
    for i=1:999
       predict_label=(predict_score>threshold(i));
       [temp_sen(i),temp_spec(i),temp_precision(i),temp_accuracy(i),temp_f1(i)]=classification_metric(interaction_score,predict_label);
    end
    [max_score,index]=max(temp_f1);
    sen=temp_sen(index);
    spec=temp_spec(index);
    precision=temp_precision(index);
    accuracy=temp_accuracy(index);
    f1=temp_f1(index);
end


function [sen,spec,precision,accuracy,f1]=classification_metric(real_label,predict_label)
    tp_index=find(real_label==1 & predict_label==1);
    tp=size(tp_index,1);

    tn_index=find(real_label==0 & predict_label==0);
    tn=size(tn_index,1);

    fp_index=find(real_label==0 & predict_label==1);
    fp=size(fp_index,1);

    fn_index=find(real_label==1 & predict_label==0);
    fn=size(fn_index,1);

    accuracy=(tn+tp)/(tn+tp+fn+fp);
    sen=tp/(tp+fn);
    recall=sen;
    spec=tn/(tn+fp);
    precision=tp/(tp+fp);
    f1=2*recall*precision/(recall+precision);
end

function area=AUPR(real,predict)
    max_value=max(predict);
    min_value=min(predict);

    threshold=min_value+(max_value-min_value)*(1:999)/1000;

    threshold=threshold';
    threshold_num=length(threshold);
    tn=zeros(threshold_num,1);
    tp=zeros(threshold_num,1);
    fn=zeros(threshold_num,1);
    fp=zeros(threshold_num,1);

    for i=1:threshold_num
        tp_index=logical(predict>=threshold(i) & real==1);
        tp(i,1)=sum(tp_index);

        tn_index=logical(predict<threshold(i) & real==0);
        tn(i,1)=sum(tn_index);

        fp_index=logical(predict>=threshold(i) & real==0);
        fp(i,1)=sum(fp_index);

        fn_index=logical(predict<threshold(i) & real==1);
        fn(i,1)=sum(fn_index);
    end

    sen=tp./(tp+fn);
    precision=tp./(tp+fp);
    recall=sen;
    x=recall;
    y=precision;
    [x,index]=sort(x);
    y=y(index,:);

    area=0;
    x(1,1)=0;
    y(1,1)=1;
    x(threshold_num+1,1)=1;
    y(threshold_num+1,1)=0;
    area=0.5*x(1)*(1+y(1));
    for i=1:threshold_num
        area=area+(y(i)+y(i+1))*(x(i+1)-x(i))/2;
    end
    % plot(x,y)
end

function area=AUC(real,predict)
    max_value=max(predict);
    min_value=min(predict);
    threshold=min_value+(max_value-min_value)*(1:999)/1000;
    threshold=threshold';
    threshold_num=length(threshold);
    tn=zeros(threshold_num,1);
    tp=zeros(threshold_num,1);
    fn=zeros(threshold_num,1);
    fp=zeros(threshold_num,1);
    for i=1:threshold_num
        tp_index=logical(predict>=threshold(i) & real==1);
        tp(i,1)=sum(tp_index);

        tn_index=logical(predict<threshold(i) & real==0);
        tn(i,1)=sum(tn_index);

        fp_index=logical(predict>=threshold(i) & real==0);
        fp(i,1)=sum(fp_index);

        fn_index=logical(predict<threshold(i) & real==1);
        fn(i,1)=sum(fn_index);
    end

    sen=tp./(tp+fn);
    spe=tn./(tn+fp);
    y=sen;
    x=1-spe;
    [x,index]=sort(x);
    y=y(index,:);
    [y,index]=sort(y);
    x=x(index,:);

    area=0;
    x(threshold_num+1,1)=1;
    y(threshold_num+1,1)=1;
    area=0.5*x(1)*y(1);
    for i=1:threshold_num
        area=area+(y(i)+y(i+1))*(x(i+1)-x(i))/2;
    end
    % plot(x,y)
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function W=optimization_similairty_matrix(feature_matrix,nearst_neighbor_matrix,tag,regulation)
   row_num=size(feature_matrix,1);
   W=zeros(1,row_num);
   if tag==1
       row_num=1;
   end
   for i=1:row_num
       nearst_neighbors=feature_matrix(logical(nearst_neighbor_matrix(i,:)'),:);   
       neighbors_num=size(nearst_neighbors,1);
       G1=repmat(feature_matrix(i,:),neighbors_num,1)-nearst_neighbors;
       G2=repmat(feature_matrix(i,:),neighbors_num,1)'-nearst_neighbors';
       if regulation=='regulation2'
         G_i=G1*G2+eye(neighbors_num);
       end
       if regulation=='regulation1'
         G_i=G1*G2;
       end
       H=2*G_i;
       f=[];
       A=[];
       if isempty(H)
           A;
       end
       
       b=[];
       Aeq=ones(neighbors_num,1)';
       beq=1;
       lb=zeros(neighbors_num,1);
       ub=[];
       options=optimset('Display','off');
       [w,fval]= quadprog(H,f,A,b,Aeq,beq,lb,ub,[],options);
       w=w';
       W(i,logical(nearst_neighbor_matrix(i,:)))=w;     
   end
end

function distance_matrix=calculate_instances(feature_matrix)
    [row_num,col_num]=size(feature_matrix);
    distance_matrix=zeros(row_num,row_num);
    for i=1:row_num
        for j=i+1:row_num
            distance_matrix(i,j)=sqrt(sum((feature_matrix(i,:)-feature_matrix(j,:)).^2));
            distance_matrix(j,i)=distance_matrix(i,j);
        end
        distance_matrix(i,i)=col_num;
    end
end

function nearst_neighbor_matrix=calculate_neighbors(distance_matrix,neighbor_num)
  [sv si]=sort(distance_matrix,2,'ascend');
  [row_num,col_num]=size(distance_matrix);
  nearst_neighbor_matrix=zeros(row_num,col_num);
  index=si(:,1:neighbor_num);
  for i=1:row_num
       nearst_neighbor_matrix(i,index(i,:))=1;
  end
end

function W=Label_Propagation(feature_matrix,tag,neighbor_num,regulation)
    distance_matrix=calculate_instances(feature_matrix);
    nearst_neighbor_matrix=calculate_neighbors(distance_matrix,neighbor_num);
    W=optimization_similairty_matrix(feature_matrix,nearst_neighbor_matrix,tag,regulation);
end

function F=calculate_labels(W,Y,alpha)
    F=(1-alpha)*pinv(eye(size(W,1))-alpha*W)*Y;
end


