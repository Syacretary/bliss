package com.syacretary.bliss

class NodeRuntimeBridge {
    external fun startNode(arguments: Array<String>, sessionKey: String): Int

    companion object {
        init {
            System.loadLibrary("node")
            System.loadLibrary("bliss_node_bridge")
        }
    }
}
