//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by Haider Rizvi on 04/02/2024.
//

import Foundation
import XCTest
import EssentialFeed

class URLSessionHTTPClient {
    private let session : URLSession
    
    init(session: URLSession = .shared){
        self.session = session
    }
    
    struct UnexpectedValuesRepresentation: Error{}
    
    func get(from url: URL, completion:@escaping (HTTPClientResult) -> Void){
        session.dataTask(with: url){ _, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(UnexpectedValuesRepresentation()))
            }
        }.resume()
    }
    
}

class  URLSessionHTTPClientTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        URLProtocolStub.startInterceptingRequests()
    }
    
    override class func tearDown() {
        super.tearDown()
        
        URLProtocolStub.stopInterceptingRequests()
    }
    
    func test_getFromURL_performGetRequestWithURL() {
        let url = anyURL()
        
        let exp = expectation(description: "Wait for request")
        
        URLProtocolStub.observeRequests{ request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }
        
        makeSUT().get(from: url){ _ in }
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_failsOnRequestError(){
        
        let requestError  = anyNSError()
        let receivedError =  resultErrorFor(data: nil, response: nil, error: requestError)
        
        XCTAssertNotNil(receivedError)
    }
    
    func test_getFromURL_failsOnAllNilValues(){
        
        XCTAssertNotNil(resultErrorFor(data:nil, response:nil, error:nil))
        
    }
    
    func test_getFromURL_failsOnAllInvalidRepresentationCases(){
        XCTAssertNotNil(resultErrorFor(data:nil, response:nonHTTPURLResponse(), error:nil))
        XCTAssertNotNil(resultErrorFor(data:nil, response:anyHTTPURLResponse(), error:nil))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nil, error:nil))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nil, error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:nil, response:nonHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:nil, response:anyHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nonHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:anyHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nonHTTPURLResponse(), error:nil))
        
    }
    
    // Mark: - Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> URLSessionHTTPClient {
        let sut = URLSessionHTTPClient()
        trackForMemoryLeaks(sut,file: file, line: line)
        return sut
    }
    
    private func resultErrorFor(data: Data?, response:URLResponse?, error: Error?,file: StaticString = #filePath, line: UInt = #line) -> Error? {
        let url = anyURL()
        URLProtocolStub.stub(data: data, response: response, error: error)
        
        let sut = makeSUT(file:file, line: line)
        let exp = expectation(description: "Wait for completion")
        var receivedError: Error?
        
        sut.get(from: url) {result in
            switch result {
            case let .failure(error):
                receivedError = error
            default:
                XCTFail("Expected failure got \(result) instead", file:file, line: line)
            }
            
            exp.fulfill()
            
        }
        wait(for: [exp], timeout: 1.0)
        
        return receivedError
    }
    
    private func anyURL() -> URL {
        return URL(string: "http://any-url.com")!
    }
    
    private func anyData() -> Data  {
        return Data(bytes: "any data".utf8)
    }
    
    private func anyNSError() -> NSError {
        return NSError(domain: "any error", code: 0)
    }
    
    private  func nonHTTPURLResponse() -> URLResponse {
        return URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
    
    private func anyHTTPURLResponse() -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
    
    
    private class URLProtocolStub: URLProtocol {
        
        private static var stub : Stub?
        private static var  requestObserver : ((URLRequest) -> Void)?
        
        private struct Stub {
            let data:  Data?
            let response: URLResponse?
            let error : Error?
        }
        
        static func stub(data: Data?, response: URLResponse?, error: Error? =  nil){
            stub = Stub(data:data, response: response, error: error)
        }
        
        static func observeRequests(observer:@escaping (URLRequest) -> Void){
            requestObserver = observer
        }
        
        static func startInterceptingRequests(){
            URLProtocolStub.registerClass(URLProtocolStub.self)
        }
        
        static func stopInterceptingRequests(){
            URLProtocolStub.unregisterClass(URLProtocolStub.self)
            stub = nil
            requestObserver = nil
        }
        
        override class func canInit(with request: URLRequest) -> Bool {
            requestObserver?(request)
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            
            if let data = URLProtocolStub.stub?.data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            if let response = URLProtocolStub.stub?.response  {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let error  = URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            }
            
            client?.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {}
        
        
    }
    
}