<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>InstallmentSetPaidFalse</fullName>
        <field>Paid__c</field>
        <literalValue>0</literalValue>
        <name>Installment Set Paid False</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>InstallmentSetPaidTrue</fullName>
        <field>Paid__c</field>
        <literalValue>1</literalValue>
        <name>Installment Set Paid True</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>InstallmentSyncAmount</fullName>
        <field>Amount__c</field>
        <formula>Opportunity__r.Amount</formula>
        <name>Installment Sync Amount</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>InstallmentSyncCheckDate</fullName>
        <field>Check_Date__c</field>
        <formula>Opportunity__r.Check_Date__c</formula>
        <name>Installment Sync Check Date</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>InstallmentSyncCheckNumber</fullName>
        <field>Check_Number__c</field>
        <formula>Opportunity__r.Check_Number__c</formula>
        <name>Installment Sync Check Number</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>InstallmentSyncDate</fullName>
        <field>Date__c</field>
        <formula>Opportunity__r.CloseDate</formula>
        <name>Installment Sync Date</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
</Workflow>
