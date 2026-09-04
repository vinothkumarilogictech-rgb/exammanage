class DashboardStats {
  final int totalBranches, totalExams, todayExams, todayCandidates, tomorrowCandidates, totalAttendedCandidates;
  final String today, tomorrow;
  DashboardStats({
    required this.totalBranches,
    required this.totalExams,
    required this.todayExams,
    required this.todayCandidates,
    required this.tomorrowCandidates,
    required this.totalAttendedCandidates,
    required this.today,
    required this.tomorrow,
  });
  factory DashboardStats.fromMap(Map<String, dynamic> m) => DashboardStats(
    totalBranches: int.tryParse('${m['total_branches'] ?? 0}') ?? 0,
    totalExams: int.tryParse('${m['total_exams'] ?? 0}') ?? 0,
    todayExams: int.tryParse('${m['today_exams'] ?? 0}') ?? 0,
    todayCandidates: int.tryParse('${m['today_candidates'] ?? 0}') ?? 0,
    tomorrowCandidates: int.tryParse('${m['tomorrow_candidates'] ?? 0}') ?? 0,
    totalAttendedCandidates: int.tryParse('${m['total_attended_candidates'] ?? 0}') ?? 0,
    today: '${m['today'] ?? ''}',
    tomorrow: '${m['tomorrow'] ?? ''}',
  );
}

class DashboardBranch {
  final int id, todayExams, todayCandidates, tomorrowCandidates, totalScheduled;
  final String name, status;
  DashboardBranch({
    required this.id,
    required this.name,
    required this.status,
    required this.todayExams,
    required this.todayCandidates,
    required this.tomorrowCandidates,
    required this.totalScheduled,
  });
  factory DashboardBranch.fromMap(Map<String, dynamic> m) => DashboardBranch(
    id: m['id'] ?? 0,
    name: '${m['name'] ?? ''}',
    status: '${m['status'] ?? ''}',
    todayExams: int.tryParse('${m['today_exams'] ?? 0}') ?? 0,
    todayCandidates: int.tryParse('${m['today_candidates'] ?? 0}') ?? 0,
    tomorrowCandidates: int.tryParse('${m['tomorrow_candidates'] ?? 0}') ?? 0,
    totalScheduled: int.tryParse('${m['total_scheduled'] ?? 0}') ?? 0,
  );
}

class DashboardExam {
  final String branchName, examTypeName, date, startTime, endTime, status;
  final int candidateCount;
  DashboardExam({required this.branchName, required this.examTypeName, required this.date, required this.startTime, required this.endTime, required this.status, required this.candidateCount});
  factory DashboardExam.fromMap(Map<String, dynamic> m) => DashboardExam(
    branchName: '${m['branch_name'] ?? ''}',
    examTypeName: '${m['exam_type_name'] ?? ''}',
    date: '${m['date'] ?? ''}',
    startTime: '${m['start_time'] ?? ''}',
    endTime: '${m['end_time'] ?? ''}',
    status: '${m['status'] ?? ''}',
    candidateCount: int.tryParse('${m['candidate_count'] ?? 0}') ?? 0,
  );
}

class TomorrowBranchCandidates {
  final String branchName;
  final int candidateCount;
  final Map<String, dynamic> examBreakdown;
  TomorrowBranchCandidates({required this.branchName, required this.candidateCount, required this.examBreakdown});
  factory TomorrowBranchCandidates.fromMap(Map<String, dynamic> m) => TomorrowBranchCandidates(
    branchName: '${m['branch_name'] ?? ''}',
    candidateCount: int.tryParse('${m['candidate_count'] ?? 0}') ?? 0,
    examBreakdown: Map<String, dynamic>.from(m['exam_breakdown'] ?? {}),
  );
}

class AttendedCandidate {
  final int attemptId, candidateId, attemptNumber;
  final String candidateName, registerNumber, examTypeName, branchName, attendedDate, result, remarks;
  AttendedCandidate({required this.attemptId, required this.candidateId, required this.attemptNumber, required this.candidateName, required this.registerNumber, required this.examTypeName, required this.branchName, required this.attendedDate, required this.result, required this.remarks});
  factory AttendedCandidate.fromMap(Map<String, dynamic> m) => AttendedCandidate(
    attemptId: m['attempt_id'] ?? 0,
    candidateId: m['candidate_id'] ?? 0,
    attemptNumber: m['attempt_number'] ?? 1,
    candidateName: '${m['candidate_name'] ?? ''}',
    registerNumber: '${m['register_number'] ?? ''}',
    examTypeName: '${m['exam_type_name'] ?? ''}',
    branchName: '${m['branch_name'] ?? ''}',
    attendedDate: '${m['attended_date'] ?? ''}',
    result: '${m['result'] ?? ''}',
    remarks: '${m['remarks'] ?? ''}',
  );
}

class Branch {
  final int id; final String name, address, contact, region, status;
  Branch({required this.id, required this.name, required this.address, required this.contact, required this.region, required this.status});
  factory Branch.fromMap(Map<String,dynamic> m)=>Branch(id:m['id']??0,name:'${m['branch_name']??''}',address:'${m['address']??''}',contact:'${m['contact_info']??''}',region:'${m['region']??''}',status:'${m['status']??''}');
}

class ExamSession {
  final int id; final String examType, branch, date, start, end, status; final double fee; final int capacity;
  ExamSession({required this.id,required this.examType,required this.branch,required this.date,required this.start,required this.end,required this.status,required this.fee,required this.capacity});
  factory ExamSession.fromMap(Map<String,dynamic> m)=>ExamSession(id:m['id']??0,examType:'${m['exam_type_name']??''}',branch:'${m['branch_name']??''}',date:'${m['exam_date']??''}',start:'${m['start_time']??''}',end:'${m['end_time']??''}',status:'${m['status']??''}',fee:double.tryParse('${m['fee']??0}')??0,capacity:int.tryParse('${m['seat_capacity']??0}')??0);
}

class ExamTeam {
  final int id;
  final String name, location, phone, examTypeName, status;
  final int? examTypeId;
  final int candidateCount;

  ExamTeam({
    required this.id, required this.name, required this.location, required this.phone,
    required this.examTypeName, required this.status, this.examTypeId, required this.candidateCount,
  });

  factory ExamTeam.fromMap(Map<String, dynamic> m) => ExamTeam(
    id: m['id'] ?? 0,
    name: '${m['name'] ?? ''}',
    location: '${m['location'] ?? ''}',
    phone: '${m['phone'] ?? ''}',
    examTypeName: '${m['exam_type_name'] ?? ''}',
    status: '${m['status'] ?? 'Active'}',
    examTypeId: m['exam_type_id'] is int ? m['exam_type_id'] : int.tryParse('${m['exam_type_id']}'),
    candidateCount: int.tryParse('${m['candidate_count'] ?? 0}') ?? 0,
  );
}

class Candidate {
  final int id; final String name,email,phone,registerNumber,status,branch,examType,date,teamName;
  Candidate({required this.id,required this.name,required this.email,required this.phone,required this.registerNumber,required this.status,required this.branch,required this.examType,required this.date,required this.teamName});
  factory Candidate.fromMap(Map<String,dynamic> m)=>Candidate(id:m['id']??0,name:'${m['name']??''}',email:'${m['email']??''}',phone:'${m['phone']??''}',registerNumber:'${m['register_number']??''}',status:'${m['status']??''}',branch:'${m['branch_name']??''}',examType:'${m['exam_type_name']??''}',date:'${m['exam_date']??''}',teamName:'${m['team_name']??''}');
}

class Expense {
  final int id;
  final int? categoryId;
  final int? branchId;
  final int? employeeId;
  final String category, description, date, branch, paymentMode, status, employeeName;
  final double amount;

  Expense({
    required this.id,
    this.categoryId,
    this.branchId,
    this.employeeId,
    required this.category,
    required this.description,
    required this.date,
    required this.branch,
    required this.paymentMode,
    required this.status,
    required this.amount,
    this.employeeName = '', 
  });

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] ?? 0,
        categoryId: m['category_id'] is int ? m['category_id'] : int.tryParse('${m['category_id']}'),
        employeeId: m['employee_id'] is int ? m['employee_id'] : int.tryParse('${m['employee_id']}'),
        branchId: m['branch_id'] is int ? m['branch_id'] : int.tryParse('${m['branch_id']}'),
        category: '${m['category_name'] ?? m['category'] ?? ''}',
        description: '${m['description'] ?? m['note'] ?? ''}',
        date: '${m['date_incurred'] ?? ''}',
        branch: '${m['branch_name'] ?? ''}',
        paymentMode: '${m['payment_mode'] ?? ''}',
        status: '${m['status'] ?? 'Active'}',
        amount: double.tryParse('${m['amount'] ?? 0}') ?? 0,
        employeeName: '${m['employee_name'] ?? ''}',
      );
}

class VoucherPurchaseInvoiceItem {
  final int id;
  final int examTypeId;
  final String examName;
  final int quantity;
  final double unitPrice, discount, tax, totalAmount;

  VoucherPurchaseInvoiceItem({
    required this.id,
    required this.examTypeId,
    required this.examName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.tax,
    required this.totalAmount,
  });

  factory VoucherPurchaseInvoiceItem.fromMap(Map<String, dynamic> m) =>
      VoucherPurchaseInvoiceItem(
        id: int.tryParse('${m['id'] ?? 0}') ?? 0,
        examTypeId: int.tryParse('${m['exam_type_id'] ?? 0}') ?? 0,
        examName: '${m['exam_name'] ?? '-'}',
        quantity: int.tryParse('${m['quantity'] ?? 0}') ?? 0,
        unitPrice: double.tryParse('${m['unit_price'] ?? 0}') ?? 0,
        discount: double.tryParse('${m['discount'] ?? 0}') ?? 0,
        tax: double.tryParse('${m['tax'] ?? 0}') ?? 0,
        totalAmount: double.tryParse('${m['total_amount'] ?? 0}') ?? 0,
      );
}

class VoucherPurchaseInvoice {
  final int id;
  final String invoiceNumber, supplier, invoiceDate, branchName, paymentStatus, paymentMode, paymentReference, notes, status;
  final int branchId;
  final double subtotal, discount, tax, totalAmount, paidAmount, balanceAmount;
  final List<VoucherPurchaseInvoiceItem> items;

  VoucherPurchaseInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.supplier,
    required this.invoiceDate,
    required this.branchId,
    required this.branchName,
    required this.paymentStatus,
    required this.paymentMode,
    required this.paymentReference,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.notes,
    required this.status,
    required this.items,
  });

  factory VoucherPurchaseInvoice.fromMap(Map<String, dynamic> m) =>
      VoucherPurchaseInvoice(
        id: int.tryParse('${m['id'] ?? 0}') ?? 0,
        invoiceNumber: '${m['invoice_number'] ?? ''}',
        supplier: '${m['supplier'] ?? ''}',
        invoiceDate: '${m['invoice_date'] ?? ''}',
        branchId: int.tryParse('${m['branch_id'] ?? 0}') ?? 0,
        branchName: '${m['branch_name'] ?? ''}',
        paymentStatus: '${m['payment_status'] ?? 'Pending'}',
        paymentMode: '${m['payment_mode'] ?? ''}',
        paymentReference: '${m['payment_reference'] ?? ''}',
        subtotal: double.tryParse('${m['subtotal'] ?? 0}') ?? 0,
        discount: double.tryParse('${m['discount'] ?? 0}') ?? 0,
        tax: double.tryParse('${m['tax'] ?? 0}') ?? 0,
        totalAmount: double.tryParse('${m['total_amount'] ?? 0}') ?? 0,
        paidAmount: double.tryParse('${m['paid_amount'] ?? 0}') ?? 0,
        balanceAmount: double.tryParse('${m['balance_amount'] ?? 0}') ?? 0,
        notes: '${m['notes'] ?? ''}',
        status: '${m['status'] ?? 'Active'}',
        items: (m['items'] as List? ?? const [])
            .map((x) => VoucherPurchaseInvoiceItem.fromMap(Map<String, dynamic>.from(x)))
            .toList(),
      );
}

class ExpenseCategoryItem {
  final int id;
  final String name;
  final String status;
  final String createdAt;

  ExpenseCategoryItem({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  factory ExpenseCategoryItem.fromMap(Map<String, dynamic> m) => ExpenseCategoryItem(
        id: m['id'] ?? 0,
        name: '${m['name'] ?? ''}',
        status: '${m['status'] ?? 'Active'}',
        createdAt: '${m['created_at'] ?? ''}',
      );
}

class ExamTypeItem {
  final int id;
  final String name;
  final String language;
  final String description;
  final String status;

  ExamTypeItem({
    required this.id,
    required this.name,
    required this.language,
    required this.description,
    required this.status,
  });

  factory ExamTypeItem.fromMap(Map<String, dynamic> m) => ExamTypeItem(
        id: m['id'] ?? 0,
        name: '${m['name'] ?? ''}',
        language: '${m['language'] ?? 'English'}',
        description: '${m['description'] ?? ''}',
        status: '${m['status'] ?? 'Active'}',
      );
}



class Employee {
  final int id;
  final String employeeId, fullName, designation, phone, email, address, joiningDate, status, branchName;
  final int branchId;
  final double basicSalary;
  Employee({required this.id, required this.employeeId, required this.fullName, required this.designation, required this.phone, required this.email, required this.address, required this.joiningDate, required this.status, required this.branchId, required this.branchName, required this.basicSalary});
  factory Employee.fromMap(Map<String,dynamic> m) => Employee(
    id: m['id'] ?? 0, employeeId: '${m['employee_id'] ?? m['employee_code'] ?? ''}', fullName: '${m['full_name'] ?? m['name'] ?? ''}', designation: '${m['designation'] ?? ''}', phone: '${m['contact_number'] ?? m['phone'] ?? ''}', email: '${m['email'] ?? ''}', address: '${m['address'] ?? ''}', joiningDate: '${m['joining_date'] ?? ''}', status: '${m['status'] ?? 'Active'}', branchId: int.tryParse('${m['branch_id'] ?? 0}') ?? 0, branchName: '${m['branch_name'] ?? ''}', basicSalary: double.tryParse('${m['basic_salary'] ?? 0}') ?? 0,
  );
}
