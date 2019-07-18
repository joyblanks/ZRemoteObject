/**
* @Author : Joy
* Create Date : 04/01/2016
* 
* ZRemoteObject
* Custom Remote Object Model
* Framework to handle Remote object call on a complex object
* 
* Usage:
* 
*	VISUALFORCE PAGE :
*	<apex:remoteObjects>
*		<apex:remoteObjectModel name="<AnyObject>" fields="<CommaSeperatedFields>" retrieve="{!$RemoteAction.<YourCustomController>.<YourCustomFunctionRemoteAction>}" />
*	</apex:remoteObjects>
*
*	______________________________________________________________________________________________________	
*	
*	-- SCRIPT --
*	var model = new SObjectModel.<AnyDefinedObjectAbove>(); //Define once use it everywhere.
*
*	var fetchOptions = {
*		limit	: 100
*		,offset	: 300 //**When passing multiple objects offset needs to be an object {Opportunity : 100, Lead : 30} #Lookup:001 //You need to store the offsets in UI to page backward. 
*		,orderby: [{status : 'ASC'}] //If Multiple only first object will be considered as Primary in SOQL building, if multiple mapping then SOQL Orderby is ignored and sortList is invoked.
*		,view	: val //Can pass any custom object if required in @RemoteAction and will be ignored by the Framework
*		//mapping can be multiple objects -> data is collated in a single list and referred to as the keys so from JSON records[i].status will hold (StageName in Opportunity and Status in Lead)
*		,mapping: {
*			 Opportunity: {id: 'id', ownerLastName: 'Owner.LastName', name: 'Account.Name', firstName: 'Account.FirstName', status: 'StageName', subStatus : |*#Lookup:002*|{formula:'{0}=="Closed Won"?{1}:{2}',fieldset:['StageName','ERP_Won_Status__c','Reason_Lost__c']}}
*			,Lead 		: {id: 'id', ownerLastName : 'Owner.LastName', name : 'name', firstName: 'firstName', status: 'Status', subStatus: 'Unqualified_Declined_Reason__c', extra : 'Referral_Code__c'}
*		}
*		,where	: {
*			Referral_Program__c: { in: ['BAC', 'BAC Enterprise'] } , status : {in : ['Unqualified', 'Closed Lost']	 } //status is the key and qualified name for (StageName in Opportunity and Status in Lead)
*		}
*	};;
*
*	model.retrieve(JSON.stringify(fetchOptions),function(records,error,event){
*		//records -> Standard field (will not hold data anymore)
*		//error -> on error
*		//event.result -> will have the JSON object sent from ZRemoteObject.cls
*		//<return new Map<String, Object> {'records' => results, 'countRecords' => countRecords};> -> event.result.records and event.result.countRecords can be accessed here.
*	});
*	
*	______________________________________________________________________________________________________
*	
*	#Lookup:001 
*	NOTE: You can call your javascript anyhow you like this is just one way of doing things.
*	//only in case of wrappers
*	//(In case if you have one object to deal with you can supply an integer offset 
*	// -- which is multiple of your limit it will work and you don't need this [eg 100, 200, 300, etc when limit = 100])
*	
*	Step : 1
*	//Declare these following variables in a clousure accessible to below fn <gatherOffset>
*	var offset			= 0;
*	var mappedOffset	= {};
*	var pagedOffsets	= [];
*	var paged			= 0;
*	var workset			= {};
*	var totalCount		= 0;
*	
*	Step : 2
*	//populate above vars
*
*	model.retrieve(JSON.stringify(fetchOptions),function(records,error,event){
*		workset = event.result.records; //will be used to determine next paging offset below fn <gatherOffset>
*		totalCount = event.result.countRecords || totalCount;
*	});
*	
*	Step : 3
*	//Call a fn that will fetch the next offset 
*	//if paged = +1 paginated forward 
*	//or paged = 0 means same page refreshed/reloaded 
*	//or paged = -1 means reverse pagination
*	
*	fetchOptions.offset = gatherOffset(workset,offset,paged,fetchOptions.mapping,mappedOffset,pagedOffsets,fetchLimit);
*	//Defined below
*	
*	Step : 4
*	//Keep calm and code away
*	var gatherOffset = function(w,o,p,s,m,ps,l){ 
*		// w = current displayed workset the recordList that is sent from here (every row in this list contains a key type of Object it is holding)
*		// o is the current offset based on number of records found out intially based on totalRecords for multiple objects
*		// p is the direction of paging +1 0 -1
*		// s is the mapping intention to check if offset will be an object or a number based on mapping
*		// m is the current mappedoffset that is sent to Remote object call e.g {Opportunity : 100, Lead : 30}
*		// ps is the array which collates all the mappedOffset so it is easy to navigate if it has the current offset pagenumber then return else locate by iterating workset
*		// l is the fetch limit
*		
*		if(Object.keys(s).length==1){
*			return !o ? undefined : o;//if there is only one mapping it will return integer say multiples of limit [eg 100, 200, 300, etc when limit = 100]
*		}else{
*			m = ps[((o||0)/l)] || {};//if paged data available/ first time load
*			if(p>0  && $.isEmptyObject(m)){ //forward paging
*				m = $.extend({},ps[((o||0)/l)-1]); //get last paging and add to it the current workset type records
*				$.each(w,function(k,v){
*					m[v.type] && m[v.type]++ || (m[v.type]=1);//determine next offset 
*				});
*			}
*			ps[((o||0)/l)] = m; //update in pagedOffset Array
*			return m;
*		}
*	};
*	______________________________________________________________________________________________________
*
* 	#Lookup:002
*		subStatus : {formula:'{0}=="Closed Won"?{1}:{2}',fieldset:['StageName','ERP_Won_Status__c','Reason_Lost__c']}	
*		Right now the formula thingy is not implemented, the recommended way is to create a formula field and put it there.
*		Complications in building formula field is the complexity as it is called multiple times and APEX has something called Tooling API 
*		other methods to "ExecuteAnnonymousCode" didn't do the trick (can be looked into in the future)
*	______________________________________________________________________________________________________
*	
*	APEX CONTROLLER (@RemoteAction)
*	
*	@RemoteAction
*	public static Map<String, Object> retrieveData(String type, List<String> fields, String criteria){
*		
*		// 1) One way of doing things deserialize it and obtain proper objects (will be marshalled)
*		
*		Map<String, Object> criteriaMap = (Map<String, Object>)JSON.deserializeUntyped(criteria);
*		List<Map<String,Object>> results = ZRemoteObject.fetch(criteriaMap);
*		Integer countRecords = ZRemoteObject.countQuery(criteriaMap);
*		Map<String, Object> customResult = new Map<String, Object> {'records' => results, 'countRecords' => countRecords};
*		return customResult;
*		//------------------//
*		
*		// 2) Another way of doing things pass String directly and obtain proper objects (will be marshalled)
*		
*		List<Map<String,Object>> results = ZRemoteObject.fetch(criteria);
*		Integer countRecords = ZRemoteObject.countQuery(criteria);
*		Map<String, Object> customResult = new Map<String, Object> {'records' => results, 'countRecords' => countRecords};
*		return customResult;
*		//------------------//
*		
*		// 3) Can directly pass string and JSON will be marshalled
*		return ZRemoteObject.fetchWithCount(criteria);	1 call to get records and total count 
*	}
*
**/

public class ZRemoteObject{
	//private final static variables
	private static final String SPACE 						= ' ';
	private static final String BLANK 						= '';
	private static final String DOT 						= '.';
	private static final String COMMA 						= ',';
	private static final String SINGLE_QUOTE				= '\'';
	private static final Integer DEF_LIMIT 					= 100;
	private static final Integer MAX_OFFSET					= 2000;
	private static final boolean SORT_CASE_INSENSITIVE 		= true;
	private static final List<String> BRACKET				= new List<String>{'(',')'};
	private static final String MAPPING_KEY			 		= 'mapping';
	private static final String DATE_YYYYMMDD 				= 'yyyyddMM';
	private static final Pattern SOQL_NO_INJECT 			= Pattern.compile('(?i)(\'\\s+OR\\s+)|(\'\\s+AND\\s+)|(\'\\s+UNION\\s+)|(\'\\s*--+)');
	private static final SOQLConstants SOQL_CONSTANT 		= new SOQLConstants();
	
	private class SOQLConstants{
		public String q_AND 								= 'and';
		public String q_OR 									= 'or';
		public String q_SELECT 								= 'select';
		public String q_FROM 								= 'from';
		public String q_WHERE 								= 'where';
		public String q_LIMIT 								= 'limit';
		public String q_OFFSET 								= 'offset';
		public String q_ORDERBY								= 'order by';
		public String q_COUNT								= 'count()';
		public String k_ORDERBY								= 'orderby';
		public String v_ASC									= 'ASC';
		public String v_DESC								= 'DESC';
		public Map<String, String> OPERATORS 				= new Map<String,String>{'eq'=>'=', 'ne'=>'!=', 'like'=>'like', 'gte'=>'>=', 'lte'=>'<=', 'gt'=>'>', 'lt'=>'<', 'in'=>'in', 'nin'=>'not in'};
	}
	
	/**
	* ZRemoteObject :: fetch()
	* Public function to access the results pass the fetchoptions JSON to get a list of results
	*
	* @param Map<String, Object> criteria
	* @return List<Map<String,String>> grid
	*
	*/
	public static List<Map<String,Object>> fetch(Map<String, Object> criteria){
		String soql;
		List<sObject> tmpList;
		List<Map<String,Object>> grid = new List<Map<String,Object>>();
		if(!criteria.containsKey(MAPPING_KEY)){
			throw new ZRemoteObjectException('Missing mandatory field (mapping)', criteria);
		}
		
		Map<String, Object> mapping = (Map<String,Object>)criteria.get(MAPPING_KEY);
		Integer limitField = criteria.get(SOQL_CONSTANT.q_LIMIT) == null ? DEF_LIMIT : (Integer)criteria.get(SOQL_CONSTANT.q_LIMIT);
		
		for (String objectName : mapping.keySet()){
			soql = queryMaker(criteria, objectName);
			tmpList = Database.query(soql);
			tmpList = offsetHacked(tmpList,limitField,offsetClause(criteria.get(SOQL_CONSTANT.q_OFFSET), objectName, true));//Offset 2000+ paging
			grid.addAll(generateGrid(tmpList,mapping,objectName));
			System.Debug(LoggingLevel.INFO, 'ZRemoteObject:fetch : query > ' + objectName + '('+tmpList.size()+') - ' + soql);
		}
		
		//  * If mapping consists multiple objects then use clipped which actually clips based on limit || 100 
		//	- since objects fetches limit * <object Count> 
		//  - Incase of single object orderby is carried by ORDER BY Clause from SOQL
		if(mapping.keySet().size()>1){
			if(criteria.containsKey(SOQL_CONSTANT.k_ORDERBY)){
				Map<String,Object> orderBy = (Map<String,Object>)((List<Object>)criteria.get(SOQL_CONSTANT.k_ORDERBY))[0];
				String sortCol = new List<String>(((Set<String>)orderBy.keySet()))[0];
				boolean sortDir = ((String)((List<Object>)orderBy.values())[0]).contains(SOQL_CONSTANT.v_ASC);
				grid = sortList(grid, sortCol, sortDir);
			}
			grid = clipped(grid,limitField);//here		
		}
		System.Debug(LoggingLevel.INFO, 'ZRemoteObject:fetch : list > '+grid);
		return grid;
	}
	
	/**
	* ZRemoteObject :: countQuery()
	* Call function to iterate fetchOptions to find count of records passed from Remote Object call 
	*
	* @param Map<String, Object> fieldMap
	* @return Integer countRecords
	*
	*/
	public static Integer countQuery(Map<String, Object> fieldMap){
		String query;
		Map<String, Object> objectMapper;
		Integer countRecords 				= 0;
		Integer tempCount					= 0;
		Map<String, Object> mapping 		= (Map<String,Object>)fieldMap.get(MAPPING_KEY);
		
		for (String objectName : mapping.keySet()){
			objectMapper = (Map<String,Object>)mapping.get(objectName);
			query = SOQL_CONSTANT.q_SELECT + SPACE + SOQL_CONSTANT.q_COUNT + SPACE + SOQL_CONSTANT.q_FROM + SPACE + objectName;//countQuery
			if(fieldMap.containsKey(SOQL_CONSTANT.q_WHERE)){
				query += SPACE + SOQL_CONSTANT.q_WHERE + SPACE + whereClause((Map<String,Object>)fieldMap.get(SOQL_CONSTANT.q_WHERE), null, objectMapper);
			}
			tempCount = database.countQuery(query);
			countRecords += tempCount;
			System.Debug(LoggingLevel.INFO, 'ZRemoteObject:countQuery - query > ' + objectName + '('+tempCount+') - ' + query);
		}
		System.Debug(LoggingLevel.INFO, 'ZRemoteObject:countQuery - total > '+countRecords);
		return countRecords;
	}
	
	/**
	* ZRemoteObject :: fetchWithCount()
	* Public function to access the results pass the fetchoptions JSON to get a Map of results and count
	*
	* @param String criteria
	* @return Map<String, Object> outputStructure
	*
	*/
	public static Map<String, Object> fetchWithCount(String criteria){
		Map<String, Object> criteriaMap = (Map<String, Object>)JSON.deserializeUntyped(criteria);
		return new Map<String, Object> {'records' => fetch(criteriaMap), 'countRecords' => countQuery(criteriaMap)};
	}
	
	/**
	* ZRemoteObject :: fetch()
	* --overloaded method signature;
	* Public function to access the results pass the fetchoptions JSON to get a list of results
	*
	* @param String criteria
	* @return List<Map<String,String>> grid
	*
	*/
	public static List<Map<String,Object>> fetch(String criteria){
		return fetch((Map<String, Object>)JSON.deserializeUntyped(criteria));
	}
	
	/**
	* ZRemoteObject :: countQuery()
	* --overloaded method signature;
	* Call function to iterate fetchOptions to find count of records passed from Remote Object call 
	*
	* @param String str
	* @return Integer countRecords
	*
	*/
	public static Integer countQuery(String criteria){
		return countQuery((Map<String, Object>)JSON.deserializeUntyped(criteria));
	}
	
	/**
	* ZRemoteObject :: generateGrid()
	* Helper method (private) Calls function to iterate on SOQL results 
	* to build the display Object 
	*
	* @param List<sObject> soqlResults
	* @param Map<String, Object> mapping
	* @param String objectName
	* @return List<Map<String,String>> grid
	*
	*/
	private static List<Map<String,Object>> generateGrid(List<sObject> soqlResults, Map<String, Object> mapping, String objectName){
		Map<String,Object> v;
		Map<String, Object> tmp;
		List<Object> complxFields;
		List<Map<String,Object>> grid 		= new List<Map<String,Object>>();
		Map<String, Object> objectMapper 	= (Map<String,Object>)mapping.get(objectName);
		
		for(sObject o : soqlResults){
			v = new Map<String,Object>();
			v.put('type',objectName);
			for (String fieldName : objectMapper.keySet()){
				if(objectMapper.get(fieldName) instanceof String){
					v.put(fieldName,getAlias(o,(String)objectMapper.get(fieldName)));
				}else {
					//to be discontinued
					tmp = (Map<String, Object>)objectMapper.get(fieldName);
					complxFields = (List<Object>)tmp.get('fieldset');
					for(Object f : complxFields){
						v.put((String)f,getAlias(o,(String)f));
					}
				}
			}
			grid.add(v);
		}
		return grid;
	}
	
	/**
	* ZRemoteObject :: sortList()
	* Helper method (private) Calls function to sort result List 
	*
	* IDEA: 
	*	- A Map of List of Map of custom_Objects The key of the main map is the sort col value, 
	* 	- This is a Map of List because there might be same values so those values are appended as list
	*	- Then the Map keyset is sorted and then iterated and a new list is generated based on the sorted Map's keyset list
	*	- for options like Case sensitive / insensitive refer function getSortKey() below
	*
	* @param List<Map<String,Object>> list
	* @param String sortCol
	* @param boolean sorDir
	* @return List<Map<String,Object>> list
	*
	*/
	private static List<Map<String,Object>> sortList(List<Map<String,Object>> myList, String sortCol, boolean sortDir){
		List<Map<String,Object>> finalList				= new List<Map<String,Object>>();
		Map<String,List<Map<String,Object>>> dataMap 	= new Map<String,List<Map<String,Object>>>();
		
		for(Map<String,Object> a : myList){
			if(dataMap.containsKey(getSortKey(a.get(sortCol))))
				dataMap.get(getSortKey(a.get(sortCol))).add(a);		 
			else
				dataMap.put(getSortKey(a.get(sortCol)),new List<Map<String,Object>>{a}); 
		}
		
		List<String> keyList = new List<String>(dataMap.keySet());
		keyList.sort();
		
		Integer size = keyList.size();
		for(Integer i=0; i<size; i++){
			if(sortDir){
				finalList.addAll(dataMap.get(keyList[i])); 
			}else{
				finalList.addAll(dataMap.get(keyList[size-i-1]));
			}
		}
		return finalList;
	}
	
	/**
	* ZRemoteObject :: getSortKey()
	* Helper method (private) Calls function for String key comparison for sortList 
	* - depends on option SORT_CASE_INSENSITIVE 
	*
	* @param Object o
	* @return String s
	*
	*/
	private static String getSortKey(Object o){
		String s;
		if(o == null){
			s = BLANK;
		}else if(o instanceof Date){
			s = ((Date)o).format();
		}else if(o instanceof DateTime){
			s = ((DateTime)o).format(DATE_YYYYMMDD);
		}else if(o instanceof boolean || o instanceof Integer){
			s = String.valueOf(o);
		}else {
			s = ((String)o);
		}
		return SORT_CASE_INSENSITIVE ? s.toUpperCase() : s;
	}

	/**
	* ZRemoteObject :: getAlias()
	* Helper method (private) Calls function to reveal value from Field or Lookup field
	*
	* return type = Object Primitive to Salesforce as it can be anything Date/String/boolean/Integer/Object 
	*
	* @param sObject o
	* @param String fieldKey
	* @return String fieldValue
	*
	* NOTE: Salesforce cannot go 3 levels deep in class specifications so no point of recursive iteration can be 1 or 2 or 3. //removed code based on complexity
	*/
	private static Object getAlias(sObject o, String fieldKey){
		Object value;
		try{
			if(!fieldKey.contains(DOT)){
				value = o.get(fieldKey);
			}else{
				List<String> fieldVals = fieldKey.split('\\'+DOT);
				Integer size = fieldVals.size();
				if(size == 2){
					value = o.getSObject(fieldVals[0]).get(fieldVals[1]);
				}else if(size == 3){
					value = o.getSObject(fieldVals[0]).getSObject(fieldVals[0]).get(fieldVals[2]);
				}else 
					value = BLANK;
			}
		}catch(Exception e){
			value = null;
			//There can be any number of exceptions it was a poor choice to handle 
			//Such as DUMMY column name or blank for to show no data in wrapper combo
			// child parent maybe null etc return blanks to UI
		}
		return value == null ? BLANK : value;
	}
	
	/**
	* ZRemoteObject :: clipped()
	* pathetic sorting hack get limit * 2 then sort return limit
	* salesforce doesn't have sublist functionality
	* This is the dataset that is returned to UI
	*
	**/
	private static List<Map<String,Object>> clipped(List<Map<String,Object>> grid, Integer l){
		List<Map<String,Object>> newGrid 	= new List<Map<String,Object>>();
		Integer lastIndex 					= Math.min(grid.size(), l);
		for(Integer i=0; i<lastIndex; i++){
			newGrid.add(grid.get(i));
		}
		return newGrid;
	}
	
	/**
	* ZRemoteObject :: offsetHacked()
	* Use this to clip a subset when 2000+ offset limit is reached and page forward else return the same list
	* 
	* @param List<sObject> tmpList
	* @param Integer l
	* @param Integer o
	* @return List<sObject> newList
	*
	**/
	private static List<sObject> offsetHacked(List<sObject> tmpList, Integer l, Integer o){
		if(o<MAX_OFFSET)
			return tmpList;
		
		List<sObject> newList = new List<sObject>();
		Integer size = tmpList.size();
		for(Integer i=o; i<size; i++){
			newList.add(tmpList.get(i));
		}
		return newList;
	}
	
	/**
	* ZRemoteObject :: queryMaker()
	* Helper method (private) Calls function to iterate fetchOptions 
	* to build the options of SOQL query passed from Remote Object call 
	*
	* @param Map<String, Object> fieldMap
	* @param String objectName
	* @return String SOQLClause
	*
	*/
	private static String queryMaker(Map<String, Object> fieldMap,String objectName){
		String query = BLANK, tmp;
		Map<String, Object> mapping 		= (Map<String,Object>)fieldMap.get(MAPPING_KEY);
		
		Map<String, Object> objectMapper 	= (Map<String,Object>)mapping.get(objectName);
		
		query += selectClause(objectName, objectMapper); //SELECT
		
		if(fieldMap.containsKey(SOQL_CONSTANT.q_WHERE)){
			query += SPACE + SOQL_CONSTANT.q_WHERE + SPACE + whereClause((Map<String,Object>)fieldMap.get(SOQL_CONSTANT.q_WHERE), null, objectMapper); //WHERE
		}
		
		if(fieldMap.containsKey(SOQL_CONSTANT.k_ORDERBY)){ //ORDER BY
			//Removed && mapping.keySet().size()==1 since it has to be sorted on both data sets based on individual data and then on screen
			tmp = orderByClause((List<Object>)fieldMap.get(SOQL_CONSTANT.k_ORDERBY),objectMapper);
			query += tmp.length() == 0 ? BLANK : (SPACE + SOQL_CONSTANT.q_ORDERBY + SPACE + tmp);
		}
		
		query += SPACE + SOQL_CONSTANT.q_LIMIT + SPACE + String.valueOf(limitClause(fieldMap,objectName)); //LIMIT
		
		if(fieldMap.containsKey(SOQL_CONSTANT.q_OFFSET)){ //OFFSET
			Object offsetVal = fieldMap.get(SOQL_CONSTANT.q_OFFSET);
			if(offsetVal !=null && offsetVal instanceof Integer && mapping.keySet().size()>1){
				throw new ZRemoteObjectException('Offset needs to be an object in case of multiple mapping', offsetVal);
			}
			Integer tmpOff = offsetClause(fieldMap.get(SOQL_CONSTANT.q_OFFSET), objectName, false);
			query += tmpOff==null ? BLANK : (SPACE + SOQL_CONSTANT.q_OFFSET + SPACE + String.valueOf(tmpOff));
		}
		
		return query;
	}
	
	/**
	* ZRemoteObject :: selectClause()
	* Helper method (private) Calls function to iterate fetchOptions.mapping.object
	* to build the select of SOQL query passed from Remote Object call 
	*
	* @param String objectName
	* @param Map<String, Object> objectMapper
	* @return String SelectClause
	*
	*/
	private static String selectClause(String objectName, Map<String, Object> objectMapper){
		Map<String, Object> tmp;
		Set<String> fieldVals = new Set<String>();
		for (String fieldName : objectMapper.keySet()){
			if(objectMapper.get(fieldName) instanceof String){
				if(!BLANK.equalsIgnoreCase((String)objectMapper.get(fieldName))){
					fieldVals.add((String)objectMapper.get(fieldName));
				}
			}else {
				//to be discontinued
				tmp = (Map<String, Object>)objectMapper.get(fieldName);
				for(Object v : (List<Object>)tmp.get('fieldset')){
					fieldVals.add((String)v);
				}
			}
		}
		return SOQL_CONSTANT.q_SELECT + SPACE + String.join(new List<String>(fieldVals),COMMA) + SPACE + SOQL_CONSTANT.q_FROM + SPACE + objectName;
	}
	
	/**
	* ZRemoteObject :: whereClause()
	*	<--recursive function-->
	*
	* Helper method (private) Calls function recursively to iterate in depth 
	* to build the 'WHERE' of SOQL query passed from Remote Object call 
	*
	*
	* @param Map<String,Object> clauseObj
	* @param String keyField
	* @param Map<String,Object> mapping
	* @return String whereClause
	*
	*/
	private static String whereClause(Map<String,Object> clauseObj, String keyField, Map<String,Object> objectMapper){
		String temp;
		String whereString = BLANK;
		if(keyField == null){
			whereString = BLANK;
			for (String key : clauseObj.keySet()){
				temp = whereClause(clauseObj,key,objectMapper);
				whereString += BLANK.equalsIgnoreCase(temp) ? BLANK : (whereString.length()==0 ? SPACE : SPACE + SOQL_CONSTANT.q_AND + SPACE) + temp;
			}
			return whereString;
		}
		if(keyField.equalsIgnoreCase(SOQL_CONSTANT.q_OR) || keyField.equalsIgnoreCase(SOQL_CONSTANT.q_AND)){
			whereString = BLANK;
			Map<String,Object> subClause = (Map<String,Object>)clauseObj.get(keyField);
			for (String key : subClause.keySet()){
				temp = whereClause(subClause,key,objectMapper);
				whereString += BLANK.equalsIgnoreCase(temp) ? BLANK : (whereString.length()==0 ? BLANK : SPACE+keyField+SPACE) + temp;
			}
			return + SPACE + BRACKET[0] + whereString + BRACKET[1] + SPACE;
		}
		
		Map<String,Object> field 	= (Map<String,Object>)clauseObj.get(keyField);
		String compareKey 			= new List<String>(field.keySet())[0];
		
		if(compareKey.equalsIgnoreCase(SOQL_CONSTANT.q_OR) || compareKey.equalsIgnoreCase(SOQL_CONSTANT.q_AND)){
			return whereClause(field,compareKey,objectMapper);
		}else{
			if(objectMapper.containsKey(keyField) && objectMapper.get(keyField) instanceof String && BLANK.equalsIgnoreCase((String)objectMapper.get(keyField))){
				return BLANK;//For Dummy mapping in wrappers
			} 
			return validateWhere((objectMapper.containsKey(keyField) && (objectMapper.get(keyField) instanceof String) ? (String)objectMapper.get(keyField) : keyField) ,  SOQL_CONSTANT.OPERATORS.get(compareKey) , field.get(compareKey));
		}
		return SPACE;
	}
	
	/**
	* ZRemoteObject :: orderByClause()
	* Helper method (private) Calls function to iterate in List of items 
	* to build the 'ORDER BY' of SOQL query passed from Remote Object call 
	*
	* @param List<Object> orderBys
	* @param Map<String, Object> objectMapper
	* @return String orderByClause
	*
	*/
	private static String orderByClause(List<Object> orderBys, Map<String, Object> objectMapper){
		Map<String,Object> field;
		String orderByString = BLANK;
		for (Object orderBy : orderBys){
			field = (Map<String,Object>)orderBy;
			if(!(objectMapper.get(new List<String>(((Set<String>)field.keySet()))[0]) instanceof String)){
				continue;
			}
			orderByString += (orderByString.length()==0 ? SPACE : COMMA) + (String)objectMapper.get(new List<String>(((Set<String>)field.keySet()))[0]) + SPACE + ((List<Object>)field.values())[0];
		}
		return orderByString;
	}
	
	/**
	* ZRemoteObject :: offsetClause()
	* Helper method (private) Calls function to iterate in List of items 
	* to build the 'OFFSET' of SOQL query passed from Remote Object call
	* Holds capability to send multiple offset based on object name if offset passed is an JS Object 
	*
	* @param Object offsetVal
	* @param String objectName
	* @param boolean actual
	* @return Integer offset
	*
	*/
	private static Integer offsetClause(Object offsetVal,String objectName, boolean actual){
		Integer oVal = null;
		if(null == offsetVal){
			oVal = null;
		}else if(offsetVal instanceof Integer){
			oVal = (Integer)offsetVal;
		}else {
			Map<String, Object> offsetMap = (Map<String, Object>)offsetVal;
			if(offsetMap!=null && offsetMap.containsKey(objectName)){
				oVal = (Integer)offsetMap.get(objectName);
			}
		}
		return actual ? oVal == null ? 0 : oVal : oVal == null || oVal >= MAX_OFFSET ? null : oVal;
	}
	
	/**
	* ZRemoteObject :: limitClause()
	* Helper method (private) Calls function to iterate in List of items 
	* to build the 'LIMIT' of SOQL query passed from Remote Object call
	* If Offset < 2000 then send actual limit else no offset and limit = offset(js tracked) + limit 
	*
	* @param Map<String, Object> fieldMap
	* @param String objectName
	* @return Integer limit
	*
	*/
	private static Integer limitClause(Map<String, Object> fieldMap, String objectName){
		Integer oVal 		= offsetClause(fieldMap.get(SOQL_CONSTANT.q_OFFSET), objectName, true);
		Integer limitVal 	= (fieldMap.containsKey(SOQL_CONSTANT.q_LIMIT) ? (Integer)fieldMap.get(SOQL_CONSTANT.q_LIMIT) : DEF_LIMIT);
		if(oVal >= MAX_OFFSET){
			limitVal = oVal + limitVal;
		}
		return limitVal;
	}
	
	/**
	* ZRemoteObject :: evolve()
	* Helper method (private) Calls function to manipulate input data for SOQL
	* used in whereClause fn
	*
	* @param Object o
	* @return String o-manipulated
	*
	*/
	private static String evolve(Object o){
		String value;
		if(o instanceof String && ((String)o).equals('TODAY')){
			value =  (String)o;
		}else if(o instanceOf Integer || o instanceOf Boolean){
			value = String.valueOf(o);
		}else if(o instanceOf String){
			if(SOQL_NO_INJECT.matcher((String)o).find()){
				throw new ZRemoteObjectException('Hey you MORON what are you trying to do?', o);
			}
			value = SINGLE_QUOTE + String.escapeSingleQuotes((String)o) + SINGLE_QUOTE;
		}else if(o instanceOf List<Object>){
			List<Object> oTmp = (List<Object>)o;
			if(SOQL_NO_INJECT.matcher(String.join(oTmp,COMMA)).find()){
				throw new ZRemoteObjectException('Hey you MORON what are you trying to do?', o);
			}
			if(oTmp[0] instanceOf String){
				value = BRACKET[0] + SINGLE_QUOTE + String.join(oTmp, (SINGLE_QUOTE + COMMA + SINGLE_QUOTE)) + SINGLE_QUOTE + BRACKET[1];
			}else{
				value = BRACKET[0] + String.join(oTmp,COMMA) + BRACKET[1];
			}
		}else{
			value =  SPACE;
		}	
		return value;
	}
	
	/**
	* ZRemoteObject :: validateWhere()
	* Helper method (private) Calls function to manipulate input data for SOQL
	* used in whereClause fn
	*
	* @param String fld
	* @param String com
	* @param Object val
	* @return String clause
	*
	*/
	private static String validateWhere(String fld, String com, Object val){
		//TODO : hook for Future -> Try a class level variable Map to store values and use them in a prepared statement to be full proof 
		return fld + SPACE + com + SPACE + evolve(val);
	}
	
	/**
	* ZRemoteObjectException
	* Custom Exception class
	**/
	public virtual class ZRemoteObjectException extends Exception{
		public Object o;
		public ZRemoteObjectException(String message, Object o){
			this(message);
			this.o = o;
		}
	}
	
}