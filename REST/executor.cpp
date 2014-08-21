#include <stdio.h>
#include <iostream>
#include <vector>
#include <sstream>
#include <string>
#include <stdint.h>
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <boost/property_tree/xml_parser.hpp>


#include <pqxx/pqxx>

#include "executor.hpp"
#include "strutil.hpp"
#include <sha.h>

using namespace ourapi;

using boost::property_tree::ptree;
using std::make_pair;
using std::vector;


Executor::Executor()
{
}

/*
******************************
Getting UID from MAC functions
******************************
*/
bool Executor::uid(const args_container &args, outputType type, string & response){
	std::stringstream ss;
	ss << "SELECT uid from uid where hash=decode('"<< generatehash(args.mac)<<"','hex');";
	return Executor::generic_query(response,ss.str());
}

bool write_uid(pqxx::result & res,string & response){
  ptree root_t;
  root_t.put("uid",res[0][0]);
  std::ostringstream oss;
  write_json(oss,root_t);
  response = oss.str();
  return true;
}
/*
*******************************
Getting last N entries function
*******************************
*/
bool Executor::last(const args_container &args, outputType type, string & response,const string & url){
  std::stringstream ss;
  if( url == "/client"){
    ss << "select * from client_last(" << args.uid <<")";
  }
  else if( url == "/ap"){
    ss << "select * from device_last(" << args.uid << ")";
  }
  else { // Not yet implemented API or invalid API
    return false;
  }
  if(atoi(args.last.c_str()) > MAX_ENTRIES){
    ss << " order by tro DESC limit " << MAX_ENTRIES + 1<<" ;";
  }
  else {
    ss << " order by tro DESC limit " << args.last <<" ;";
  }
  //std::cout<<"Query:"<<ss.str()<<std::endl;
  return Executor::generic_query(response,ss.str());
}

bool write_last_std(pqxx::result & res, string & response){
	ptree root_t;
  ptree children;
  unsigned int size;
  std::string limit_reached; // yes or no
  if(res.size() > MAX_ENTRIES){
    size = MAX_ENTRIES;
    limit_reached = "yes";
  }
  else{
    size = res.size();
    limit_reached = "no";
  }
  root_t.put("size",size);
  root_t.put("limit reached",limit_reached);
  for(unsigned int rownum = 0 ;rownum < res.size(); rownum++){
    ptree child;
    child.put("device_id",res[rownum][0]);
    child.put("client_id",res[rownum][1]);
    child.put("from",res[rownum][2]);
    child.put("to",res[rownum][3]);
    children.push_back(make_pair("",child));
  }
  root_t.add_child("log entries",children);
  std::stringstream ss;
  write_json(ss,root_t);
  response = ss.str();
  return true;
}
/*
*****************************************************************
COUNT API - returns count of distinct connections made to all APs
*****************************************************************
*/
bool Executor::count(const args_container &args, outputType type, string & response,const string & url){
  std::stringstream ss;
  ss << "SELECT * FROM all_count('" << args.from <<"','";
  ss << args.to << "','" << args.format<<"');";
  std::cout <<"Making query:" << ss.str() << std::endl;
  return Executor::generic_query(response,ss.str());
}
bool Executor::count_at(const args_container &args, outputType type, string & response,const string & url){
  std::stringstream ss,ss2;
  std::vector<std::string> tmp;
  if(args.building) tmp.push_back("building");
  if(args.floor) tmp.push_back("floor");
  if(args.wing) tmp.push_back("wing");
  if(args.room) tmp.push_back("room");
  for(unsigned int i = 0;i<tmp.size();i++){
    if(i == tmp.size()-1){
      ss2 << tmp.at(i);
      continue;
    }
    ss2 << tmp.at(i) <<",";
  }
  ss << "SELECT " << ss2.str() << ",sum(count) from at_all_count('" << args.at;
  ss << "','"<<args.format<<"') join label on device_id = uid GROUP BY ";
  ss << ss2.str() << " ORDER BY building;";
  std::cout << "Making Query:"<<ss.str()<<std::endl;
  return Executor::generic_query(response,ss.str());
}

/*
************************************************
Getting entries between two dates+times function
************************************************
*/
bool Executor::std(const args_container &args, outputType type, string & response,const string & url){
  std::stringstream ss;
  if( url == "/client"){
    ss << "select * from client_std('" << args.from <<"','" << args.to << "','";
    ss << args.format << "',"<<args.uid<<")";
  }
  else if( url == "/ap"){
    ss << "select * from device_std('" << args.from <<"','" << args.to << "','";
    ss << args.format << "',"<<args.uid<<")";
  }
  else { // Not yet implemented API or invalid API
    return false;
  }
  ss << " order by fro limit "<< MAX_ENTRIES + 1 << ";"; // +1 to check if limit exceeded
  std::cout<<"Making query:"<<ss.str()<<std::endl;
  return Executor::generic_query(response,ss.str());
}
/*
************************************************
Function to generate json for count type queries
************************************************
*/
bool write_count(pqxx::result & res, std::string & response){
  ptree root_t,children;
  for(size_t i = 0; i<res.size(); i++){
    ptree child;
    child.put("device_id",res[i][0]);
    child.put("batch",res[i][1]);
    child.put("count",res[i][2]);
    children.push_back(make_pair("",child));
  }
  root_t.add_child("counts",children);
  std::stringstream ss;
  write_json(ss,root_t);
  response = ss.str();
  return true;
}
/*
********************************
Function to get live connections
********************************
*/
bool Executor::live(const args_container &args, outputType type, string & response,const string & url){
  std::stringstream ss;
  if(url == "/live"){
    ss << "SELECT * from get_live_table()";
    return Executor::generic_query(response,ss.str());
  }
  else{
    return false;
  }
}

bool write_live(pqxx::result & res, std::string & response){
  ptree root_t,children;
  root_t.put("size",res.size());
  for(unsigned int row = 0 ;row < res.size(); row++){
    ptree child;
    child.put("client_id",res[row][0]);
    child.put("device_id",res[row][1]);
    child.put("timestamp",res[row][2]);
    children.push_back(make_pair("",child));
  }
  root_t.add_child("live connections",children);
  std::stringstream ss;
  write_json(ss,root_t);
  response = ss.str();
  return true;
}
/*
*****************************
Function to execute SQL query
*****************************
*/
bool Executor::generic_query(string & response, const string query){
  try{
    pqxx::connection conn("dbname=mydb user=postgres password=admin hostaddr=127.0.0.1 port=5432");
    if(!conn.is_open()){
      return false;
    }
    pqxx::work w(conn);
    pqxx::result res = w.exec(query);
    w.commit();
    //TBD: Maybe some checking on pqxx::result itself
    if(query_type == VALID_API_UID){
      return write_uid(res,response);
    }
    else if(query_type == VALID_API_COUNT){
      return write_count(res,response); 
    }
    else if(query_type == VALID_API_LIVE){
      return write_live(res,response); 
    }
    else { // Write standard or last
      return write_last_std(res,response);
    }
  }
  catch(const std::exception & e){
    std::cerr<<e.what()<<std::endl;
    return false;
  }
  response = "API not ready yet"; // Remove before issuing a pull request
  return true;
}
